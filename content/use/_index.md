+++
title = "Use CRaC"
description = ""
weight = 20
+++

<!--
CRaC allows to start Java applications that are already initialized and warmed-up.
Deployment scheme reflects the need to collect the required data.
-->

CRaC deployment scheme reflects the need to collect data required for Java application initialization and warm-up.

![Operation Flow](/images/flow/flow.png)

1. a Java application (or container) is deployed in the canary environment
    * the app processes canary requests that triggers class loading and JIT compilation
2. the running application is checkpointed by some mean
    * this creates the image of the JVM and application; the image is considered as a part of a new deployment bundle
3. the Java application with the image are deployed in the production environment
    * the restored Java process uses loaded classes from and JIT code from the immediately

**WARNING**: next is a proposal phase and is subject to change

Please refer to the [Projects with CRaC support](#projects-with-crac-support) section, [step-by-step guide](STEP-BY-STEP.md) or [best practices guide](best-practices.md) to get an application with CRaC support.
The rest of the section is written for the [spring-boot example](#spring-boot).

For the first, Java command line parameter `-XX:CRaCCheckpointTo=PATH` defines a path to store the image and also allows the java instance to be checkpointed.
By the current implementation, the image is a directory with image files.
The directory will be created if it does not exist, but no parent directories are created.

```sh
export JAVA_HOME=./jdk
$JAVA_HOME/bin/java -XX:CRaCCheckpointTo=cr -jar target/example-spring-boot-0.0.1-SNAPSHOT.jar
```

For the second, in another console: supply canary worload ...

```sh
$ curl localhost:8080
Greetings from Spring Boot!
```

... and make a checkpoint by a jcmd command

```sh
$ jcmd target/example-spring-boot-0.0.1-SNAPSHOT.jar JDK.checkpoint
1563568:
Command executed successfully
```

Due to current jcmd implementation, success is always reported in jcmd output, problems are reported in the console of the application.

Another option to make the checkpoint is to invoke the `jdk.crac.Core.checkpointRestore()` method (see [API](#api)).
More options are possible in the future.

For the third, restore the `cr` image by `-XX:CRaCRestoreFrom=PATH` option

```sh
$JAVA_HOME/bin/java -XX:CRaCRestoreFrom=cr
```