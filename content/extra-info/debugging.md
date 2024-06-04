+++
title = "Debugging"
weight = 20
+++

## Debugging checkpoint and restore failures

This guide will help you identify common problems when the checkpoint operation does not work.

### Failures in native C/R

When the checkpoint operation fails in the native part, there is usually little information in the stack trace of the exception:

```sh
CR: Checkpoint ...
JVM: invalid info for restore provided: queued code -1
Exception in thread "main" jdk.crac.CheckpointException
	at java.base/jdk.crac.Core.checkpointRestore1(Core.java:159)
	at java.base/jdk.crac.Core.checkpointRestore(Core.java:264)
	at java.base/jdk.crac.Core.checkpointRestore(Core.java:249)
	at Main.main(Main.java:6)
```

Currently the C/R depends on the **CRIU** project, particularly on the [CRaC fork](https://github.com/CRaC/criu). This requires extensive privileges (capabilities) and therefore usually runs as `root` granted through the SUID bit. Therefore the first check is would be whether this is true:

```sh
$ ls -la $JAVA_HOME/lib/criu
-rwsr-xr-x 1 root root 6347736 Mar 24 16:33 /opt/openjdk-17-crac+5_linux-x64/lib/criu
   ^         ^
   |         Check that the file is owner by the root user
   Check that the SUID bit is set
```

If this is not the case please update it:

```sh
sudo chown root:root /path/to/criu
sudo chmod u+s /path/to/criu
```

This might not be sufficient if Java is running in a container; checkpoint requires running it with the `--privileged` flag (or `--cap-add all`). Restore can be executed without these privileges under root user.

When you confirm that this is set correctly but the checkpoint still fails you can get additional insight from the `dump4.log` file located in the image directory (`-XX:CRaCCheckpointTo`).

### File descriptors in Java code

Before the checkpoint the application has to isolate itself from the outer world: this means closing all file descriptors except the standard input, output and error, and few other (e.g. pointing to JDK or files on the classpath). If the application fails to do so the checkpoint fails with an exception like below:

```sh
Exception in thread "main" jdk.crac.CheckpointException
	at java.base/jdk.crac.Core.checkpointRestore1(Core.java:129)
	at java.base/jdk.crac.Core.checkpointRestore(Core.java:264)
	at java.base/jdk.crac.Core.checkpointRestore(Core.java:249)
	at ... (application code)
	Suppressed: jdk.crac.impl.CheckpointOpenFileException: FileDescriptor 4 left open: /foo/bar (regular) Use -Djdk.crac.collect-fd-stacktraces=true to find the source.
		at java.base/java.io.FileDescriptor.beforeCheckpoint(FileDescriptor.java:391)
		at java.base/java.io.FileDescriptor$Resource.beforeCheckpoint(FileDescriptor.java:84)
		at java.base/jdk.crac.impl.PriorityContext$SubContext.invokeBeforeCheckpoint(PriorityContext.java:107)
		at java.base/jdk.crac.impl.OrderedContext.runBeforeCheckpoint(OrderedContext.java:70)
		at java.base/jdk.crac.impl.AbstractContextImpl.beforeCheckpoint(AbstractContextImpl.java:81)
		at java.base/jdk.crac.impl.AbstractContextImpl.invokeBeforeCheckpoint(AbstractContextImpl.java:41)
		at java.base/jdk.crac.impl.PriorityContext.runBeforeCheckpoint(PriorityContext.java:70)
		at java.base/jdk.crac.impl.AbstractContextImpl.beforeCheckpoint(AbstractContextImpl.java:81)
		at java.base/jdk.internal.crac.JDKContext.beforeCheckpoint(JDKContext.java:97)
		at java.base/jdk.crac.impl.AbstractContextImpl.invokeBeforeCheckpoint(AbstractContextImpl.java:41)
		at java.base/jdk.crac.impl.OrderedContext.runBeforeCheckpoint(OrderedContext.java:70)
		at java.base/jdk.crac.impl.AbstractContextImpl.beforeCheckpoint(AbstractContextImpl.java:81)
		at java.base/jdk.crac.Core.checkpointRestore1(Core.java:127)
		... 5 more
```

The top level `CheckpointException` wraps all problems as its suppressed exceptions. Here we can see that having file `/foo/bar` open as FD `4` prevents the checkpoint but unless we know what part of the application opens this file there is not anything actionable. Therefore we will run this with `-Djdk.crac.collect-fd-stacktraces=true` as the exception message suggests:

```sh
Exception in thread "main" jdk.crac.CheckpointException
	at java.base/jdk.crac.Core.checkpointRestore1(Core.java:129)
	at java.base/jdk.crac.Core.checkpointRestore(Core.java:264)
	at java.base/jdk.crac.Core.checkpointRestore(Core.java:249)
	at ... (application code)
	Suppressed: jdk.crac.impl.CheckpointOpenFileException: FileDescriptor 4 left open: /etc/passwd (regular)
		at java.base/java.io.FileDescriptor.beforeCheckpoint(FileDescriptor.java:391)
		at java.base/java.io.FileDescriptor$Resource.beforeCheckpoint(FileDescriptor.java:84)
		at java.base/jdk.crac.impl.PriorityContext$SubContext.invokeBeforeCheckpoint(PriorityContext.java:107)
		at java.base/jdk.crac.impl.OrderedContext.runBeforeCheckpoint(OrderedContext.java:70)
		at java.base/jdk.crac.impl.AbstractContextImpl.beforeCheckpoint(AbstractContextImpl.java:81)
		at java.base/jdk.crac.impl.AbstractContextImpl.invokeBeforeCheckpoint(AbstractContextImpl.java:41)
		at java.base/jdk.crac.impl.PriorityContext.runBeforeCheckpoint(PriorityContext.java:70)
		at java.base/jdk.crac.impl.AbstractContextImpl.beforeCheckpoint(AbstractContextImpl.java:81)
		at java.base/jdk.internal.crac.JDKContext.beforeCheckpoint(JDKContext.java:97)
		at java.base/jdk.crac.impl.AbstractContextImpl.invokeBeforeCheckpoint(AbstractContextImpl.java:41)
		at java.base/jdk.crac.impl.OrderedContext.runBeforeCheckpoint(OrderedContext.java:70)
		at java.base/jdk.crac.impl.AbstractContextImpl.beforeCheckpoint(AbstractContextImpl.java:81)
		at java.base/jdk.crac.Core.checkpointRestore1(Core.java:127)
		... 5 more
	Caused by: java.lang.Exception: This file descriptor was created by main at epoch:1684328308663 here
		at java.base/java.io.FileDescriptor$Resource.<init>(FileDescriptor.java:75)
		at java.base/java.io.FileDescriptor.<init>(FileDescriptor.java:104)
		at java.base/java.io.FileInputStream.<init>(FileInputStream.java:154)
		at java.base/java.io.FileInputStream.<init>(FileInputStream.java:111)
		at java.base/java.io.FileReader.<init>(FileReader.java:60)
		at ... (application code calling new FileReader("/foo/bar") )
		... 2 more
```

The cause is recorded when the FD is opened, the message shows thread name (`main`) and epoch timestamp (some FDs are open early during VM initialization when it is not possible to format the timestamp to a human-readable format). This information can help you identify the component that does not close the FD during checkpoint.

### File descriptors in native code

When the file descriptor is opened without assisting FileDescriptor instance CRaC still discovers this before the checkpoint but won't display any stack trace:

```sh
Exception in thread "main" jdk.crac.CheckpointException
	at java.base/jdk.crac.Core.checkpointRestore1(Core.java:159)
	at java.base/jdk.crac.Core.checkpointRestore(Core.java:264)
	at java.base/jdk.crac.Core.checkpointRestore(Core.java:249)
	at ... (application code)
	Suppressed: jdk.crac.impl.CheckpointOpenResourceException: FD fd=4 type=fifo path=pipe:[8953321]
		at java.base/jdk.crac.Core.translateJVMExceptions(Core.java:102)
		at java.base/jdk.crac.Core.checkpointRestore1(Core.java:163)
		... 5 more
```

In this case we need to find the source of the syscall returning the new file descriptor in native code. One tool that can help with that is `strace`:

```sh
strace -f -o /tmp/strace.txt java ...
```

This will follow forking process/thread (`-f`) and store the log in `/tmp/strace.txt`. There we can find that FDs 4 and 5 were created through the `pipe2` syscall:

```sh
1204483 pipe2([4, 5], 0)                = 0
1204483 fcntl(4, F_GETFL)               = 0 (flags O_RDONLY)
1204483 fcntl(4, F_SETFL, O_RDONLY|O_NONBLOCK) = 0
1204483 fcntl(5, F_GETFL)               = 0x1 (flags O_WRONLY)
1204483 fcntl(5, F_SETFL, O_WRONLY|O_NONBLOCK) = 0
```

Other common syscalls opening file descriptors are e.g. `openat`, `dup` or `dup2`. We will run `strace` once more, but this time filtering only one syscall (`-e pipe2`), and recording stacks (`-k`):

```sh
strace -f -o /tmp/strace.txt -e pipe2 -k java ...
```

```sh
1204650 pipe2([4, 5], 0)                = 0
 > /usr/lib/x86_64-linux-gnu/libc.so.6(pipe+0xd) [0x11522d]
 > /path/to/my/jdk/lib/libnio.so() [0x84bf]
 > unexpected_backtracing_error [0x7f2f1140f6cb]
```

We can see that the `pipe` method was called from `libnio.so` This example used a debug build of JDK so we still have symbols, so we can find the function with address `0x84bf`:

```sh
objdump -d --start-address 0x84bf /path/to/my/jdk/lib/libnio.so | head

/path/to/my/jdk/lib/libnio.so:     file format elf64-x86-64
Disassembly of section .text:

00000000000084bf <Java_sun_nio_ch_IOUtil_makePipe+0x1f>:
    84bf:	85 c0                	test   %eax,%eax
    84c1:	0f 88 c1 00 00 00    	js     8588 <Java_sun_nio_ch_IOUtil_makePipe+0xe8>
    84c7:	44 8b 65 d8          	mov    -0x28(%rbp),%r12d
```

Here we can track down the invocation to native method `makePipe()` in `sun.nio.ch.IOUtil`. You can debug your application putting a breakpoint on that method and find the rest of the Java call stack, or check manually all usages.

### Restore conflict of PIDs

Errors can happen during restore, too. While on baremetal deployments PIDs usually don't clash, in containers starting from PID 1 this is more likely. The error then looks like this:

```sh
Error (criu/cr-restore.c:1506): Can't fork for 9: File exists
Error (criu/cr-restore.c:2593): Restoring FAILED.
```

The message is a bit misleading: the error is not related to files. In this example CRIU tried to restore a process or thread with PID 9 but found that there is already an existing process/thread with this PID. If you check `ps faux` it's possible that you won't find that process - the restore itself spins up some processes that could clash and die due to unsuccessful restore. If the clash happens due to restoring process it might be sufficient to attempt the restore several times, until there is no conflict.

The error above should not be confused with another one:

```sh
Error (criu/cr-restore.c:1506): Can't fork for 9: Read-only file system
Error (criu/cr-restore.c:2593): Restoring FAILED.
Error (criu/cr-restore.c:1823): Pid 20 do not match expected 9
```

This is rather a sign that CRIU has insufficient privileges to write into `ns_last_pid` and/or call `clone3`, a syscall forking the process with a specific PID. CRIU can work around the missing permissions if it can cycle up to the desired PID, but if it is lower than the current PID it won't cycle through the full range set in the operating system.

One trick that can be used in containers is to ensure that before the checkpoint PIDs are higher than anything needed for the restore, either writing `/proc/sys/kernel/ns_last_pid` or cycling dummy processes until `ns_last_pid` is higher than the required value (128 might be a good starting point).

### Further debugging of restore

During restore CRIU writes its log into standard output with errors-only verbosity level (1). Debug-level (4) output can be enabled using VM option `-XX:CREngine=criuengine,--verbosity=4,--log-file=/path/to/log.txt` by passing these options to CRIU.
