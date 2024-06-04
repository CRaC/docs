+++
title = "Best Practices"
weight = 10
+++

## Best practices for implementing CRaC support in your application/library

This guide assumes you are already familiar with the concepts and `Resource` API; please check out the [step-by-step guide](STEP-BY-STEP.md) for those.

### Implementing Resource as inner class

In order to encapsulate the functionality, the `Resource` interface is sometimes not implemented directly by the component but we rather create an (anonymous) inner class. However it is not sufficient to pass this resource to the `Context.register()` method; Global Context tracks resources using *weak* references. As there is no `unregister` method on the Context, had a strong reference been used this would prevent the component from being garbage-collected when the application releases it. Therefore the class implementing `Resource` should be stored inside the component (in a field) to prevent garbage-collection:

```java
public class Component {
    private final Resource cracHandler;

    public Component() {
        /* other initialization */
        cracHandler = new Resource() {
            @Override
            public void beforeCheckpoint(Context<? extends Resource> context) {
                /* ... */
            }

            @Override
            public void afterRestore(Context<? extends Resource> context) {
                /* ... */
            }
        };
        /* Had we used just .register(new Resource() { ... }) in here
           it would be immediately garbage-collected. */
        Core.getGlobalContext().register(cracHandler);
    }
}
```

### Component lifecycle

Applications and its components are often designed with a simple lifecycle in mind; the application boots, then it is actively used, and in the end it enters shutdown and finally ends up in a terminated state, unable to start back. If the application needs the functionality again the component is re-created. This allows simpler reasoning and some performance optimizations by making fields final, or not protecting the access to an uninitialized component as the developer knows that it is not published yet.

While usually most of the application can stay as-is, CRaC extends the lifecycle of some components by adding the transition from active to a suspended state and back. In the suspended state, until the whole VM is terminated or before the component is restored, the rest of that application is still running and could access the component - e.g. a pool of network connections - and would find this component to be unusable at that moment. One solution is to block the thread and unblock it when the component is ready for serving again.

The implementation of this synchronization depends mostly on the threading model of the application. We will refer to the synchronized component as *resource*, even though it might not implement the `Resource` interface directly.

#### General case: unknown number of threads arriving randomly

The most general case is when we don't have any guarantees about who's calling into the resource. In order to block any access to that we will use the `java.util.concurrent.ReadWriteLock`:

```java
public class ConnectionPool implements Resource {
    private final ReadWriteLock lock = new ReentrantReadWriteLock();
    private final Lock readLock = lock.readLock();
    private final Lock writeLock = lock.writeLock();

    /* Constructor registers this Resource */

    public Connection getConnection() {
        readLock.lock();
        try {
            /* actual code fetching the connection */
            /* In this example the access to the connection itself
               is not protected and the application must be able 
               to handle a closed connection. */
        } finally {
            readLock.unlock();
        }
    }

    @Override
    public void beforeCheckpoint(Context<? extends Resource> context) throws Exception {
        writeLock.lock();
        /* close all connections */
        /* Note: if this method throws an exception CRaC will try to restore the resource
                 by calling afterRestore() - we don't need to unlock the lock here */
    }

    @Override
    public void afterRestore(Context<? extends Resource> context) throws Exception {
        try {
            /* initialize connections if needed */
        } finally {
            writeLock.unlock();
        }
    }
}
```

This solution has the obvious drawback of adding contention on the hot path, the `getConnection()` method. Even though readers won't block each other, the implementation of read locking likely has to perform some atomic writes which are not cost free.

CRaC might eventually provide an optimized version for this read-write locking pattern that would move most of the cost to the write lock (as we don't need to optimize for checkpoint performance).

#### One or known number of periodically arriving threads

When there is only a single thread, e.g. fetching a task from a queue, or known number of parties that arrive to the component often enough we can apply a more efficient solution. Let's take an example of a resource logging data to a file, and assume that the checkpoint notifications are invoked from another thread (that is the case when it is triggered through `jcmd <pid> JDK.checkpoint`). We will use the `java.util.concurrent.Phaser` rather than `j.u.c.CyclicBarrier` as the former has a non-interruptible version of waiting.

```java
public class Logger implements Resource {
    private final int N = 1; // number of threads calling write()
    private volatile Phaser phaser;

    public void write(Chunk data) throws IOException {
        checkForCheckpoint();
        /* do the actual write */
    }

    public void checkForCheckpoint() throws IOException {
        Phaser phaser = this.phaser;
        if (phaser != null) {
            if (phaser.arriveAndAwaitAdvance() < 0) {
                throw new IllegalStateException("Shouldn't terminate here");
            }
            /* now the resource is suspended */
            if (phaser.arriveAndAwaitAdvance() < 0) {
                throw new IOException("File could not be open after restore");
            }
        }
    }

    @Override
    public void beforeCheckpoint(Context<? extends Resource> context) throws Exception {
        phaser = new Phaser(N + 1); // +1 for self
        phaser.arriveAndAwaitAdvance();
        /* close file being written */
    }

    @Override
    public void afterRestore(Context<? extends Resource> context) throws Exception {
        Phaser phaser = this.phaser;
        this.phaser = null;
        try {
            /* reopen the file */
            phaser.arriveAndAwaitAdvance();
        } catch (Exception e) {
            phaser.forceTermination();
            throw e;
        }
    }
}
```

This synchronization requires only one volatile read on each `write()` call, that is generally a cheap operation. However if one of the expected threads is waiting for a long time the checkpoint would be blocked. This could be mitigated by using shorter timeouts (e.g. if the thread is polling a queue) or even actively interrupting it from the `beforeCheckpoint` method.

#### Eventloop model

Another specific case is the eventloop model where the application uses single thread for all operations in the resource and already has a mechanism to schedule task in that eventloop. Let's take an example of a resource sending a heartbeat message.

```java
public class HeartbeatManager implements Runnable, Resource {
    public final ScheduledExecutorService eventloop; // single-threaded
    public boolean suspended;

    public HeartbeatManager(Executor eventloop) {
        eventloop.scheduleAtFixedRate(this, 0, 1, TimeUnit.MINUTES);
    }

    @Override
    public void run() {
        /* send heartbeat message */
    }

    @Override
    public void beforeCheckpoint(Context<? extends Resource> context) throws Exception {
        synchronized (this) {
            HeartbeatManager self = this;
            executor.execute(() -> {
                synchronized (self) {
                    self.suspended = true;
                    self.notify();
                    while (self.suspended) {
                        self.wait();
                    }
                }
            })
            while (!suspended) {
                wait();
            }
        }
        /* shutdown */
    }

    @Override
    public void afterRestore(Context<? extends Resource> context) throws Exception {
        /* restore */
        synchronized (this) {
            suspended = false;
            notify();
        }
    }
}
```

Beware that if the single-threaded executor is shared between several components this solution is not applicable in the current form as one resource would block and the others would not be able to get suspended. In this case it might make sense to centralize the control into one resource per executor; this is out of scope of this document, though.

Also Note one detail in the example above: if the application is stopped for a long time the task scheduled by the `ScheduledExecutorService.scheduleAtFixedRate(...)`  would try to keep up after restore and perform all the missed invocations. Handling that should be a part of the `beforeCheckpoint` procedure, cancelling the task and rescheduling it again in `afterRestore`.


