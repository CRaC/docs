+++
title = "CPU Features"
weight = 30
+++

CPU features differ from host to host as newer CPUs offer support for newer
instructions, and some optional features may be removed over time. JVM (Java
Virtual Machine) depends on CPU features (such as AVX512, SSE3 etc.) of each
computer it is running on. The more CPU features JVM can use the better
performance it can provide. JVM normally uses all the CPU features it can find
on the CPU where it has started.

CRaC unfortunately cannot reconfigure an already running JVM to stop using some
of the CPU features when being restored on a CPU which is missing those
features. You may create a snapshot (`-XX:CRaCCheckpointTo=PATH`) on a newer
computer and restore it (`-XX:CRaCRestoreFrom=PATH`) on an older computer.
In such case you may see during restore a variant of error message

```sh
$JAVA_HOME/bin/java -XX:CRaCRestoreFrom=cr
You have to specify -XX:CPUFeatures=0x21421801fcfbd7,0x3e6 together with -XX:CRaCCheckpointTo when making a checkpoint file; specified -XX:CRaCRestoreFrom file contains CPU features 0x4ff7fff9dfcfbf7,0x3e6; missing features of this CPU are 0x4de3de79c000020,0x0 = 3dnowpref, adx, avx512f, avx512dq, avx512cd, avx512bw, avx512vl, sha, avx512_vpopcntdq, avx512_vpclmulqdq, avx512_vaes, avx512_vnni, clflushopt, clwb, avx512_vbmi2, avx512_vbmi, rdpid, fsrm, gfni, avx512_bitalg, pku, ospke, avx512_ifma
If you are sure it will not crash you can override this check by -XX:+UnlockExperimentalVMOptions -XX:+IgnoreCPUFeatures .
<JVM exits here>
```

Just follow the advice from the complaining system running
`-XX:CRaCRestoreFrom=PATH` when configuring the initial system creating the
snapshot (`-XX:CRaCCheckpointTo=PATH`).

```sh
$JAVA_HOME/bin/java -XX:CRaCCheckpointTo=cr -XX:CPUFeatures=0x21421801fcfbd7,0x3e6 -jar target/spring-boot-0.0.1-SNAPSHOT.jar
```

## -XX:CPUFeatures=generic

If the CRaC image is restored on computers with different CPU features the most
simple solution is to just run Java with

```sh
$JAVA_HOME/bin/java -XX:CRaCCheckpointTo=cr -XX:CPUFeatures=generic -jar target/spring-boot-0.0.1-SNAPSHOT.jar
```

Unfortunately the run then has suboptimal performance. Still the difference may
not be even measurable. For obtaining an optimal performance continue reading
[Merging CPU Features](#merging-cpu-features).

## Merging CPU Features

If the CRaC image is restored on computers with different CPU features you may
need to use `logical and` (`&`) of the suggested `-XX:CPUFeatures` option.

```text
computer A used for an image restore:
You have to specify -XX:CPUFeatures=0x21421801fcfbd7,0x3e6 together with -XX:CRaCCheckpointTo when making a checkpoint file; [...]

computer B used for an image restore:
You have to specify -XX:CPUFeatures=0x4b03c643c9869,0x173 together with -XX:CRaCCheckpointTo when making a checkpoint file; [...]

compute common minimal set of features of computers A and B:
python -c 'print(hex(0x21421801fcfbd7 & 0x4b03c643c9869)+","+hex(0x3e6 & 0x173));'
0x18003c9841,0x162

computer used for the image snapshot:
$JAVA_HOME/bin/java -XX:CRaCCheckpointTo=cr -XX:CPUFeatures=0x18003c9841,0x162 -jar target/spring-boot-0.0.1-SNAPSHOT.jar
```

## -XX:+ShowCPUFeatures

To easily detect parameters for the `-XX:CPUFeatures` option on the computer
intended to run the `-XX:CRaCRestoreFrom=PATH` option you may use the option
`-XX:+ShowCPUFeatures`. Using `--version` as in this example is not mandatory
but otherwise the CPU features may scroll away.

```sh
$JAVA_HOME/bin/java -XX:+ShowCPUFeatures --version
This machine's CPU features are: -XX:CPUFeatures=0x4ff7fff9dfcfbf7,0x3e6
CPU features being used are: -XX:CPUFeatures=0x4ff7fff9dfcfbf7,0x3e6
openjdk 22-internal 2024-03-19
OpenJDK Runtime Environment (fastdebug build 22-internal-adhoc.azul.crac-git)
OpenJDK 64-Bit Server VM (fastdebug build 22-internal-adhoc.azul.crac-git, mixed mode)
```

## -XX:+IgnoreCPUFeatures

In some cases when you get the error

```sh
$JAVA_HOME/bin/java -XX:CRaCRestoreFrom=cr
You have to specify -XX:CPUFeatures=0x21421801fcfbd7,0x3e6 together with -XX:CRaCCheckpointTo when making a checkpoint file; specified -XX:CRaCRestoreFrom file contains CPU features 0x4ff7fff9dfcfbf7,0x3e6; missing features of this CPU are 0x4de3de79c000020,0x0 = 3dnowpref, adx, avx512f, avx512dq, avx512cd, avx512bw, avx512vl, sha, avx512_vpopcntdq, avx512_vpclmulqdq, avx512_vaes, avx512_vnni, clflushopt, clwb, avx512_vbmi2, avx512_vbmi, rdpid, fsrm, gfni, avx512_bitalg, pku, ospke, avx512_ifma
If you are sure it will not crash you can override this check by -XX:+UnlockExperimentalVMOptions -XX:+IgnoreCPUFeatures .
<JVM exits here>
```

You may be sure the missing CPU feature is not really required for the run of
JVM. You can enforce JVM to run even in such a case. Logically JVM may crash by
segmentation fault (on UNIX) or other fatal error (on MS-Windows) later during
its run due to the missing CPU feature(s). You have been warned.

```sh
$JAVA_HOME/bin/java -XX:CRaCRestoreFrom=cr -XX:+UnlockExperimentalVMOptions -XX:+IgnoreCPUFeatures
You have to specify -XX:CPUFeatures=0x21421801fcfbd7,0x3e6 together with -XX:CRaCCheckpointTo when making a checkpoint file; specified -XX:CRaCRestoreFrom file contains CPU features 0x4ff7fff9dfcfbf7,0x3e6; missing features of this CPU are 0x4de3de79c000020,0x0 = 3dnowpref, adx, avx512f, avx512dq, avx512cd, avx512bw, avx512vl, sha, avx512_vpopcntdq, avx512_vpclmulqdq, avx512_vaes, avx512_vnni, clflushopt, clwb, avx512_vbmi2, avx512_vbmi, rdpid, fsrm, gfni, avx512_bitalg, pku, ospke, avx512_ifma
If you are sure it will not crash you can override this check by -XX:+UnlockExperimentalVMOptions -XX:+IgnoreCPUFeatures .
<JVM continues its execution here>
```

## -XX:CPUFeatures=ignore

If you have any problems with this CPU features handling code you can disable
it completely by:

```sh
$JAVA_HOME/bin/java -XX:CRaCCheckpointTo=cr -XX:CPUFeatures=ignore -jar target/spring-boot-0.0.1-SNAPSHOT.jar
```

Please [provide a feedback](https://mail.openjdk.org/mailman/listinfo/crac-dev)
to the CRaC project in such a case.

## -XX:CPUFeatures=native

`-XX:CPUFeatures=native` is the default. You may want to use it to override another
`-XX:CPUFeatures` option specified earlier on your command line.
