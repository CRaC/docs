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
  * [Jetty tutorial](#jetty-tutorial)
* [Examples](#examples)
  * [Tomcat / Sprint Boot](#tomcat--sprint-boot)
  * [Quarkus](#quarkus)
  * [Micronaut](#micronaut)
* [API](#api)
  * [`jdk.crac`](#`jdkcrac`)
  * [`javax.crac`](#`javaxcrac`)
  * [`org.crac`](#`orgcrac`)
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

We use [JDK builds](https://github.com/org-crac/jdk/releases/tag/release-jdk-crac) to get results for examples.

The archive should be extracted with
```
$ sudo tar zxf jdk14-crac.tar.gz
````

Source code can be found in the containing [repository](https://github.com/org-crac/jdk).

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

Please refer to (examples)(#examples) or (#jetty-tutorial) sections for getting an application with CRaC support.
The rest of the section will be written for the [spring-boot](#tomcat--sprint-boot).

For the first, Java command line parameter `-Zcheckpoint:PATH` defines a path to store the image and also allows the java instance to be checkpointed.
By the current implementation, the image is a directory with image files.
The directory will be created if it does not exist, but no parent directories are created.

```
export JAVA_HOME=./jdk
$JAVA_HOME/bin/java -Zcheckpoint:cr -jar target/spring-boot-0.0.1-SNAPSHOT.jar
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

For the third, restore the `cr` image by `-Zrestore:PATH` option

```
$JAVA_HOME/bin/java -Zrestore:cr
```

## Programmer's flow

Programs may need to be adjusted for use with Coordinated Restore.
A program can be restored in a different environment compared to the one where it was checkpointed.
Dependencies on the environment need to be detected and a coordination code need to be created to update the dependencies after restore.
Such dependencies are open handles for operating system resources like files and sockets, cached hostname and environment, registration in remote services, ...

CRaC implementation checks for existing dependencies at the checkpoint and aborts checkpoint if one is found.
Open files and sockets will be detected and reported to user, but unfortunately higher-level dependencies are impossible to detect.

The programmer's flow is demonstrated in the next tutorial.

### Jetty tutorial

This section describes CRaC support implementation for a sample Jetty application.

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
Java argument `-Zcheckpoint:PATH` enables CRaC and defines a path to store the image.

```sh
$ mvn package
$ $JAVA_HOME/bin/java -Zcheckpoint:cr -jar target/example-jetty-1.0-SNAPSHOT.jar
2020-06-29 18:01:32.944:INFO::main: Logging initialized @293ms to org.eclipse.jetty.util.log.StdErrLog
2020-06-29 18:01:33.003:INFO:oejs.Server:main: jetty-9.4.30.v20200611; built: 2020-06-11T12:34:51.929Z; git: 271836e4c1f4612f12b7bb13ef5a92a927634b0d; jvm 14-internal+0-adhoc..jdk
2020-06-29 18:01:33.045:INFO:oejs.AbstractConnector:main: Started ServerConnector@319b92f3{HTTP/1.1, (http/1.1)}{0.0.0.0:8080}
2020-06-29 18:01:33.047:INFO:oejs.Server:main: Started @406ms
```

Warm-up the application:
```
$ curl localhost:8080
Hello World
```

Use `jcmd` to trigger checkpoint:

```
$ jcmd target/example-jetty-1.0-SNAPSHOT.jar JDK.checkpoint
80694:
Command executed successfully
```

Current jcmd implementation always reports success.
For now, refer to the console of the application for diagnostic output.
In the future all diagnostic output will be provided by `jcmd`.

The expected output of the application is next.
The checkpoint cannot be created with a listening socket, the exception is thrown.

```
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
    import jdk.crac.Context;
    import jdk.crac.Core;
    import jdk.crac.Resource;

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

**N.B.**: Using of `jdk.crac` API makes compilation and execution of the example possible only on Java implementations with CRaC.
Please refer to [org.crac](#orgcrac) section for how to handle the problem.

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
```
2020-06-29 18:01:56.566:INFO:oejs.AbstractConnector:Thread-9: Stopped ServerConnector@319b92f3{HTTP/1.1, (http/1.1)}{0.0.0.0:8080}
CR: Checkpoint ...
Killed
```

The image can be used to start another instances:
```
$ $JAVA_HOME/bin/java -Zrestore:cr
2020-06-29 18:06:45.939:INFO:oejs.Server:Thread-9: jetty-9.4.30.v20200611; built: 2020-06-11T12:34:51.929Z; git: 271836e4c1f4612f12b7bb13ef5a92a927634b0d; jvm 14-internal+0-adhoc..jdk
2020-06-29 18:06:45.942:INFO:oejs.AbstractConnector:Thread-9: Started ServerConnector@319b92f3{HTTP/1.1, (http/1.1)}{0.0.0.0:8080}
2020-06-29 18:06:45.943:INFO:oejs.Server:Thread-9: Started @293756ms
```

## Examples

CRaC support in a framework allows small if any modification to applications using it.
Proof-of concept CRaC support was implemented in a few third-party frameworks and libraries.

To build the code below, you may need GitHub authorization.
1. Create once a [Personal Access Token (PAK)](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) with [packages scope](https://docs.github.com/en/packages/publishing-and-managing-packages/about-github-packages#about-tokens).
2. Provide the created PAK into `~/.m2/settings.xml` as described in [the manual](https://docs.github.com/en/packages/using-github-packages-with-your-projects-ecosystem/configuring-apache-maven-for-use-with-github-packages). Minimal file looks like
```
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <servers>
    <server>
      <id>github</id>
      <username>YOUR_USERNAME</username>
      <password>YOUR_PAK</password>
    </server>
  </servers>
</settings>
```
3. Export variables for examples that use custom `settings.xml`:
```
export GITHUB_ACTOR=YOUR_USERNAME
export GITHUB_TOKEN=YOUR_PAK
```

For the actual build instructions please refer to CI links below.
Examples usually can be built with
```
mvn -s settings.xml package
```
or
```
gradle assemble
```

### Tomcat / Sprint Boot

* [Tomcat](https://github.com/org-crac/tomcat) is a CRaC-enabled Tomcat
  * [packages](https://github.com/org-crac/tomcat/packages) is a maven repo with prebuilt packages
  * [patch](https://github.com/org-crac/tomcat/compare/8.5.x..crac) shows changes made for CRaC support to:
    * tomcat-embed libraries (used by spring-boot-example)
    * standalone Tomcat
    * build-system and CI
* [example-spring-boot](https://github.com/org-crac/example-spring-boot) is a sample Spring Boot applicaton with Tomcat
  * [patch](https://github.com/org-crac/example-spring-boot/compare/base..master) demonstrates changes made to use Tomcat with CRaC
  * [CI](https://github.com/org-crac/example-spring-boot/runs/820527073) is a run of the application on CRaC

### Quarkus

* [Quarkus](https://github.com/org-crac/quarkus)
  * [packages](https://github.com/org-crac/quarkus/packages)
  * [patch](https://github.com/org-crac/quarkus/compare/master..crac-master)
* [example-quarkus](https://github.com/org-crac/example-quarkus)
  * [patch](https://github.com/org-crac/example-quarkus/compare/base..master)
  * [CI](https://github.com/org-crac/example-quarkus/runs/816817029)

### Micronaut

* [Micronaut](https://github.com/org-crac/micronaut-core)
  * [packages](https://github.com/org-crac/micronaut-core/packages)
  * [patch](https://github.com/org-crac/micronaut-core/compare/1.3.x..crac-1.3.x)
* [example-micronaut](https://github.com/org-crac/example-micronaut)
  * [patch](https://github.com/org-crac/example-micronaut/compare/base..master)
  * [CI](https://github.com/org-crac/example-micronaut/runs/820520724)

## API

The CRaC API is not a part of Java SE specification.
We hope that eventually it will be there, until then there are different packages that can be used.

### `jdk.crac`

The package is available in the [CRaC JDK](#JDK).
* [javadoc](https://org-crac.github.io/jdk/jdk-crac/api/java.base/jdk/crac/package-summary.html)

This is the first API that is likely to get implementation.

### `javax.crac`

The package is a mirror of `jdk.crac` except the package name.
It is available in [`javax-crac` branch](https://github.com/org-crac/jdk/tree/javax-crac) of CRaC JDK and in [`javax-crac` release](https://github.com/org-crac/jdk/releases/tag/release-javax-crac) builds.

This is the API that will be proposed to inclussion into Java SE specification.
Until then, the use of the package is discuraged.

### `org.crac`

The package is provided by [org.crac](https://github.com/org-crac/org.crac) compatibility library.

The org.crac is designed to provide smooth CRaC adoption.
Users of the library can build against and use CRaC API on Java runtimes with `jdk.crac`, `javax.crac` (in the future), or without any implementation.
* In compile-time, `org.crac` package totally mirrors `jdk.crac` and `javax.crac`.
* In runtime, org.crac uses reflection to detect CRaC implementation.
If the one is available, all requests to `org.crac` are passed to the implementation.
Otherwise, requests are forwarded to a dummy implementation.

The dummy implementation allows an application to run but not to use CRaC:
* resources can be registered for notification,
* checkpoint request fails with an exception.

## Implemenation details

Current OpenJDK implementation is based on using the CRIU project to create the image.

[CRIU](https://github.com/org-crac/criu) hosts a few changes made to improve CRaC usability.

