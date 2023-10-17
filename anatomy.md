# The anatomy of CRaC processes

> Disclaimer: Consider the information on this page an insight into CRaC implementation; some of these details can change over time.

Traditional JVM process uses single multi-threaded process; on Linux (and in other POSIX OSes) the process is identified by a numerical process identifier (PID). Java considered this an OS-specific implementation detail, therefore applications tried to obtain it e.g. by parsing `ManagementFactory.getRuntimeMXBean().getName()` or in more recent Java versions (>= 9) these could use `ProcessHandle.current().pid()`. Developers usually consider this a constant for the duration of the application.

When the process terminated it exits with an exit value between 0 and 255; by convention 0 signifies success (normal exit) and other values are used for different error states. Specifically, when the process is terminated by an unhandled signal it returns exit value 128+signal.

## Basic checkpoint and restore

In the simplest form of checkpoint and restore, we have two processes: first the checkpointed one, and later on the restored process. When the C/R is performed using CRIU as a standalone binary it gets a bit more complex: CRIU, as a tool tailored for more complex use-cases than single process C/R, would attempt to checkpoint not only its primary target (the process with all its threads) but the whole process group: the process with all its children and their children. When the checkpoint is initiated from the JVM process, CRIU would be a child process, too. That's one reason why we use an intermediary process - `criuengine` - that escapes the children hierarchy and then exec's [^1] CRIU. CRIU persists the state of the original JVM process and then terminates it using KILL signal (9); that's why a process that was correctly checkpointed returns exit code 128+9 = 137.

[^1] The term *exec's* here refers to the exec in POSIX fork & exec pattern; replacing current program with a new program.

When the JVM is restored the process started with `java -XX:CRaCRestoreFrom=...` does not start the JVM; instead it exec's CRIU (through `criuengine`) which starts the restored process as its child. Since the process might have some internal dependency on its original PID, the restored child will have the same PID as the original checkpointed process. When CRIU is finished reconstruing the process it exec's into `criuengine restorewait`: the only task of this program is to wait until its only child (the restored JVM) exits and propagate its status.

However this means that now there are two processes and if a script that executed `java -XX:CRaCRestoreFrom=...` obtained this process's PID value, it is not the PID of the restored process. While `criuengine restorewait` propagates all the signals it can, KILL and STOP signals cannot be handled (propagated) and therefore the restored JVM process would not be killed but only get orphaned.

```
+--------------+
| JVM PID 1234 | <--------(persists and kills)----------------+
+--------------+                                              |
   |                        +----------------------+         +------+
   +-(escapes its parent)-> | criuengine checkpoint|-(exec)->| CRIU |
                            +----------------------+         +------+
```
```
+----------------+
| shell (script) |
+----------------+
  | (child)
  v
+--------------+         +--------------------+         +------+         +------------------------+
| java restore |-(exec)->| criuengine restore |-(exec)->| CRIU |-(exec)->| criuengine restorewait |
+--------------+         +--------------------+         +------+         +------------------------+
                                                         |                  | (child)
                                                         |                  v
                                                         |           +-----------------------+
                                                         +-(starts)->| Restored JVM PID 1234 |
                                                                     +-----------------------+
```

## Checkpointed process wrapper

In some cases, such as when running the to-be-checkpointed JVM in a container, this might get even more complicated. In containers, unless wrapping the JVM process with a shell script, this would be running with the special PID value of 1. This would prohibit the 'escape' of `criuengine checkpoint` and the checkpoint would fail. Therefore when the JVM is checkpointable and runs with PID 1 it turns into a dummy wrapper process and starts another process, the actual JVM. Therefore the container would again host two processes.

In the future there might be other situations that would follow the checkpointed JVM termination with further actions, e.g. post-processing of the process image. For seamless experience in shell this post-execution would also require a wrapper that waits until all the work is done.

If your scripts must use KILL or STOP signals these should send it to all processes within the group, e.g. using `kill -9 -<pid>`.

## Without CRIU

While CRIU offers the most mature C/R implementation the complexity of its task requires elevated capabilities, in CRaC case at least the `CAP_CHECKPOINT_RESTORE` and `CAP_SYS_PTRACE`. This might not be suitable in all deployment environments, particulary in restricted containers, and therefore the CRaC project explores other implementations as well. Theses might work with a different hierarchy of processes.

One reason for these elevated permissions is the ability to use arbitrary PIDs for new processes/threads. Java programs usually do not use its PID extensively and other C/R implementations might relax this requirement. Therefore it is highly advisable to not rely on its constness.
