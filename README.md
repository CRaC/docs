# CRaC

Coordinated Restore at Checkpoint is an OpenJDK feature that provides a fast start and immediate performance for Java applications.

A Java application and JVM are started from an image in a warmed-up form.
The image is created from a running Java instance at arbitrary point of time ("checkpoint").
The start from the image ("restore") continues from the point when checkpoint was made.

The restore in general is faster than initialization.
After the restore, Java runtime performance is also on-par with the one at the checkpoint.
So, after proper warm-up before the checkpoint, restored Java instance is able to deliver the best runtime characteristics immediately.

Coordinated Restore undisruptively introduces new before-checkpoint and after-restore phases in Java application lifecycle.
In contrast with uncoordinated checkpoint/restore, coordination allows restored Java applications to behave differently.
For example, it is possible to react on changes in execution environment that happened since checkpoint was done.

CRaC implementation creates the checkpoint only if the whole Java instance state can be stored in the image.
Resources like open files or sockets are cannot, so it is required to release them when checkpoint is made.
CRaC emits notifications for an application to prepare for the checkpoint and return to operating state after restore.

Coordinated Restore is not tied to a particular checkpoint/restore implementation and will able to use existing ones (CRIU, docker checkpoint/restore) and ones yet to be developed.

* [Results](#results)
* [JDK](#jdk)
* [User's flow](#users-flow)
* [Programmer's flow](#programmers-flow)
  * [API](#api)
    * [`jdk.crac`](#jdkcrac)
    * [`javax.crac`](#javaxcrac)
    * [`org.crac`](#orgcrac)
* [Examples](#examples)
  * [Tomcat / Sprint Boot](#tomcat--sprint-boot)
  * [Quarkus](#quarkus)
  * [Micronaut](#micronaut)
* [Implemenation details](#implemenation-details)

## Results

CRaC support was implemented in a few frameworks with next results.
The source code can be found in the [Examples](#examples) section.

<details><summary>The environment</summary>
<p>

* laptop with Intel i7-5500U, 16Gb RAM and SSD.
* Linux kernel 5.7.4-arch1-1
* data was collected in container running `ubuntu:18.04` based image
* host operating system: archlinux

---
</p>
</details>

<details><summary>How to reproduce</summary>
<p>

To reproduce you need to create a workspace directory and clone along next repositories:
* [utils](https://github.com/org-crac/utils)
* [docs](https://github.com/org-crac/docs) (this repo)
* [example-spring-boot](https://github.com/org-crac/example-spring-boot)
* [example-quarkus](https://github.com/org-crac/example-quarkus)
* [example-micronaut](https://github.com/org-crac/example-micronaut)
* [example-xml-transform](https://github.com/org-crac/example-xml-transform)

You need to build examples according [Examples](#examples) section.

Then run
```
host$ docker build -t full-bench -f Dockerfile.full-bench utils
host$ docker run -it --privileged -v $HOME:$HOME -v $PWD:$PWD -w $PWD full-bench
cont# JDK=<path/to/jdk> bash ./utils/full-bench.sh collect
...
cont# exit
host$ bash ./utils/full-bench.sh parse
host$ cp *.data docs
host$ make -C docs
```
Last command regenerates graphs in the `docs`.

---
</details>

![Startup Time](startup.png)

![Spring Boot](spring-boot.png)

![Quarkus](quarkus.png)

![Micronaut](micronaut.png)

![xml-transform](xml-transform.png)

## JDK

OpenJDK CRaC Project is developed in https://github.com/openjdk/crac.

Latest release can be found in https://crac.github.io/openjdk-builds/. The JDK archive should be extracted with `sudo`:
```
$ sudo tar zxf <jdk>.tar.gz
````

Results above were obtained with preliminary [JDK builds](https://github.com/org-crac/jdk/releases/tag/release-jdk-crac).

## User's flow
<!--
CRaC allows to start Java applications that are alreay initialized and warmed-up.
Deployment scheme reflects the need to collect the required data.
-->

CRaC deployment scheme reflects the need to collect data required for Java application initialization and warm-up.

![Operation Flow](flow.png)

1. a Java application (or container) is deployed in the canary environment
    * the app processes canary requests that triggers class loading and JIT compilation
2. the running application is checkpointed by some mean
    * this creates the image of the JVM and application; the image is considered as a part of a new deployment bundle
3. the Java application with the image are deployed in the production environment
    * the restored Java process uses loaded classes from and JIT code from the immediately

**WARNING**: next is a proposal phase and is subject to change

Please refer to [examples](#examples) sections or [step-by-step guide](STEP-BY-STEP.md) to get an application with CRaC support.
The rest of the section is written for the [spring-boot example](#tomcat--sprint-boot).

For the first, Java command line parameter `-XX:CRaCCheckpointTo=PATH` defines a path to store the image and also allows the java instance to be checkpointed.
By the current implementation, the image is a directory with image files.
The directory will be created if it does not exist, but no parent directories are created.

```
export JAVA_HOME=./jdk
$JAVA_HOME/bin/java -XX:CRaCCheckpointTo=cr -jar target/spring-boot-0.0.1-SNAPSHOT.jar
```

For the second, in another console: supply canary worload ...
```
$ curl localhost:8080
Greetings from Spring Boot!
```
... and make a checkpoint by a jcmd command
```
$ jcmd target/spring-boot-0.0.1-SNAPSHOT.jar JDK.checkpoint
1563568:
Command executed successfully
```
Due to current jcmd implementation, success is always reported in jcmd output, problems are reported in the console of the application.

Another option to make the checkpoint is to invoke the `jdk.crac.Core.checkpointRestore()` method (see [API](#api)).
More options are possible in the future.

For the third, restore the `cr` image by `-XX:CRaCRestoreFrom=PATH` option

```
$JAVA_HOME/bin/java -XX:CRaCRestoreFrom=cr
```

## Programmer's flow

Programs may need to be adjusted for use with Coordinated Restore at Checkpoint.

A [step-by-step guide](STEP-BY-STEP.md) provides information on how to implement the CRaC support in the code.

Another option is to use an existing framework with CRaC support.
There are a few frameworks available, an application need to be configured to use some of them.
Possible configuration changes for applications are below.
* [spring-boot](https://github.com/org-crac/example-spring-boot/compare/base..master)
* [quarkus](https://github.com/org-crac/example-quarkus/compare/base..master)
* [micronaut](https://github.com/org-crac/example-micronaut/compare/base..master)


### API

The CRaC API is not a part of Java SE specification.
We hope that eventually it will be there, until then there are different packages that can be used.

#### `jdk.crac`

* [javadoc](https://crac.github.io/jdk/jdk-crac/api/java.base/jdk/crac/package-summary.html)

This is the API that is implemented in the [CRaC JDK](#JDK).

Please refer to [`org.crac`](#orgcrac) if you are looking to add CRaC support to a code that should also work on a regular JDK/JRE.

#### `javax.crac`

The package is a mirror of `jdk.crac` except the package name.
It is available in [`javax-crac` branch](https://github.com/org-crac/jdk/tree/javax-crac) of CRaC JDK and in [`javax-crac` release](https://github.com/org-crac/jdk/releases/tag/release-javax-crac) builds.

This is the API that will be proposed to inclussion into Java SE specification.
Until then, the use of the package is discuraged.

#### `org.crac`

The package is provided by [org.crac](https://github.com/org-crac/org.crac) compatibility library.

The org.crac is designed to provide smooth CRaC adoption.
Users of the library can build against and use CRaC API on Java runtimes with `jdk.crac`, `javax.crac`, or without any implementation.
* In compile-time, `org.crac` package totally mirrors `jdk.crac` and `javax.crac`.
* In runtime, org.crac uses reflection to detect CRaC implementation.
If the one is available, all requests to `org.crac` are passed to the implementation.
Otherwise, requests are forwarded to a dummy implementation.

The dummy implementation allows an application to run but not to use CRaC:
* resources can be registered for notification,
* checkpoint request fails with an exception.

## Examples

CRaC support in a framework allows small if any modification to applications using it.
Proof-of concept CRaC support was implemented in a few third-party frameworks and libraries.

Source code links are below.
Builds can be found in [Maven Central](https://mvnrepository.com/artifact/io.github.crac) under `io.github.crac` artifact-id.

### Tomcat / Sprint Boot

* [Tomcat with CRaC](https://github.com/CRaC/tomcat) provides several modules
  * [Maven Central](https://mvnrepository.com/artifact/io.github.crac.org.apache.tomcat.embed/tomcat-embed-core)
  * [Changes](https://github.com/CRaC/tomcat/compare/8.5.75..crac) are:
    * for Tomcat Embed (used by spring-boot-example below):
      * `java/org/apache/tomcat/util/net/AbstractEndpoint.java`
      * `res/maven/tomcat-embed-core.pom`
    * for JDBC Pool library:
      * `modules/jdbc-pool/`
    * for standalone Tomcat (Catalina):
      * `java/org/apache/catalina/`
      * `java/org/apache/juli/`
      * `bin/`, `conf/`
    * for general build infrastructure:
      * `build.xml`, `build.properties.default`
* [Example-spring-boot](https://github.com/CRaC/example-spring-boot) is a sample Spring Boot applicaton using CRaC Tomcat
  * [Build script changes](https://github.com/CRaC/example-spring-boot/compare/base..master)
  * [CI](https://github.com/CRaC/example-spring-boot/actions) runs the application on CRaC

### Quarkus

* [Quarkus with CRaC](https://github.com/CRaC/quarkus)
  * [GitHub Packages](https://github.com/CRaC/quarkus/packages)
  * [Changes](https://github.com/CRaC/quarkus/compare/master..crac-master) are:
    * for managing vertx-http: `extensions/vertx-http/`
* [Example-quarkus](https://github.com/CRaC/example-quarkus) is a sample app on Quarkus with CRaC
  * [Build script changes](https://github.com/CRaC/example-quarkus/compare/base..master)
  * [CI](https://github.com/CRaC/example-quarkus/actions)

### Micronaut

* [Micronaut with CRaC](https://github.com/CRaC/micronaut-core)
  * [Maven Central](https://mvnrepository.com/artifact/io.github.crac.io.micronaut)
  * [Changes](https://github.com/CRaC/micronaut-core/compare/v1.3.7..crac-v1.3.7) are:
    * for managing Netty: `http-server-netty/`
    * for publishing artifacts: `gradle.properties`, `gradle/*`
* [Example-micronaut](https://github.com/CRaC/example-micronaut) is a sample app on Micronaut with CRaC
  * [Build script changes](https://github.com/CRaC/example-micronaut/compare/base..master)
  * [CI](https://github.com/CRaC/example-micronaut/actions)

## Implemenation details

Current OpenJDK implementation is based on using the CRIU project to create the image.

[CRIU](https://github.com/CRaC/criu) hosts a few changes made to improve CRaC usability.

