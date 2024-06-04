+++
title = "Jetty"
weight = 20
+++

## Step-by-step CRaC support for a Jetty app

A program can be restored in a different environment compared to the one where it was checkpointed.
Dependencies on the environment need to be detected and a coordination code need to be created to update the dependencies after restore.
Such dependencies are open handles for operating system resources like files and sockets, cached hostname and environment, registration in remote services, ...

For now, CRaC implementation checks for open files and sockets at the checkpoint.
The checkpoint is aborted if one is found, also, an exception is thrown with a description of the file name or socket address.

This document describes how to implement CRaC support on an example of a sample Jetty application.

Full source code for this section can be found in [example-jetty](https://github.com/org-crac/example-jetty) repo.
Commit history corresponds to the steps of the tutorial with greater details.

A simple Jetty application will serve as a starting point:

```java
class ServerManager {
    Server server;

    public ServerManager(int port, Handler handler) throws Exception {
        server = new Server(8080);
        server.setHandler(handler);
        server.start();
    }
}

public class App extends AbstractHandler
{
    static ServerManager serverManager;

    public void handle(...) {
        response.getWriter().println("Hello World");
    }

    public static void main(String[] args) throws Exception {
        serverManager = new ServerManager(8080, new App());
    }
}
```

The main thread creates an instance of `ServerManager` that starts managing a jetty instance.
The thread then exits, leaving the jetty instance a single non-daemon thread.

Build and start the example.
Java argument `-XX:CRaCCheckpointTo=PATH` enables CRaC and defines a path to store the image.

Use CRaC API requires adding [org.crac](https://github.com/CRaC/org.crac) as a maven dependency,
- In compile-time, org.crac package totally mirrors jdk.crac and javax.crac.
- In runtime, org.crac uses reflection to detect CRaC implementation. If the one is available,
all requests to org.crac are passed to the implementation. Otherwise, requests are forwarded to a dummy implementation.

```xml
<dependency>
  <groupId>org.crac</groupId>
  <artifactId>crac</artifactId>
  <version>0.1.3</version>
</dependency>
```

```sh
$ mvn package
$ $JAVA_HOME/bin/java -XX:CRaCCheckpointTo=cr -jar target/example-jetty-1.0-SNAPSHOT.jar
2020-06-29 18:01:32.944:INFO::main: Logging initialized @293ms to org.eclipse.jetty.util.log.StdErrLog
2020-06-29 18:01:33.003:INFO:oejs.Server:main: jetty-9.4.30.v20200611; built: 2020-06-11T12:34:51.929Z; git: 271836e4c1f4612f12b7bb13ef5a92a927634b0d; jvm 14-internal+0-adhoc..jdk
2020-06-29 18:01:33.045:INFO:oejs.AbstractConnector:main: Started ServerConnector@319b92f3{HTTP/1.1, (http/1.1)}{0.0.0.0:8080}
2020-06-29 18:01:33.047:INFO:oejs.Server:main: Started @406ms
```

Warm-up the application:

```sh
$ curl localhost:8080
Hello World
```

Use `jcmd` to trigger checkpoint:

```sh
$ jcmd target/example-jetty-1.0-SNAPSHOT.jar JDK.checkpoint
80694:
Command executed successfully
```

Current jcmd implementation always reports success.
For now, refer to the console of the application for diagnostic output.
In the future all diagnostic output will be provided by `jcmd`.

The expected output of the application is next.
The checkpoint cannot be created with a listening socket, the exception is thrown.

```sh
jdk.crac.impl.CheckpointOpenSocketException: tcp6 localAddr :: localPort 8080 remoteAddr :: remotePort 0
        at java.base/jdk.crac.Core.translateJVMExceptions(Core.java:80)
        at java.base/jdk.crac.Core.checkpointRestore1(Core.java:137)
        at java.base/jdk.crac.Core.checkpointRestore(Core.java:177)
        at java.base/jdk.crac.Core.lambda$checkpointRestoreInternal$0(Core.java:194)
        at java.base/java.lang.Thread.run(Thread.java:832)
```

Simpliest way to ensure the socket is closed is to shutdown the Jetty instance when checkpoint is started and start the instance again after restore.
For this:

1. Implement methods that are used for notification
     ```java
    import org.crac.Context;
    import org.crac.Core;
    import org.crac.Resource;

    class ServerManager implements Resource {
    ...
        @Override
        public void beforeCheckpoint(Context<? extends Resource> context) throws Exception {
            server.stop();
        }

        @Override
        public void afterRestore(Context<? extends Resource> context) throws Exception {
            server.start();
        }
    }
    ```
2. Register the object in a `Context` that will invoke the `Resource`'s methods as notification.
There is a global `Context` that can be used as default choice.
     ```java
        public ServerManager(int port, Handler handler) throws Exception {
            ...
            Core.getGlobalContext().register(this);
        }
    ```

This example is a special by presence of a single non-daemon thread owned by Jetty that keeps JVM from exit.
When `server.stop()` is called the thread exits and so does the JVM instead of the checkpoint.
To prevent this and for simplicity of example, we add another non-daemon thread that makes JVM running when the Jetty stops.
```java
    public ServerManager(int port, Handler handler) throws Exception {
        ...
        Core.getGlobalContext().register(this);

        preventExitThread = new Thread(() -> {
            while (true) {
                try {
                    Thread.sleep(1_000_000);
                } catch (InterruptedException e) {
                }
            }
        });
        preventExitThread.start();
    }
```

Now `jcmd` should make the app to print next in the console and exit:

```sh
2020-06-29 18:01:56.566:INFO:oejs.AbstractConnector:Thread-9: Stopped ServerConnector@319b92f3{HTTP/1.1, (http/1.1)}{0.0.0.0:8080}
CR: Checkpoint ...
Killed
```

The image can be used to start another instances:

```sh
$ $JAVA_HOME/bin/java -XX:CRaCRestoreFrom=cr
2020-06-29 18:06:45.939:INFO:oejs.Server:Thread-9: jetty-9.4.30.v20200611; built: 2020-06-11T12:34:51.929Z; git: 271836e4c1f4612f12b7bb13ef5a92a927634b0d; jvm 14-internal+0-adhoc..jdk
2020-06-29 18:06:45.942:INFO:oejs.AbstractConnector:Thread-9: Started ServerConnector@319b92f3{HTTP/1.1, (http/1.1)}{0.0.0.0:8080}
2020-06-29 18:06:45.943:INFO:oejs.Server:Thread-9: Started @293756ms
```


