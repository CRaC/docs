+++
title = "Quarkus Super Heroes"
weight = 25
+++

This guide will walk you through the process of taking an existing non-trivial application and getting it CRaC-able. The [workshop](https://quarkus.io/quarkus-workshops/super-heroes/spine.html) describes the application, please refer there for any details. We'll start right away with the result of that workshop:

1. Make sure that JAVA_HOME points to OpenJDK CRaC JDK, and ensure that CRaC works (CRIU has correct permissions etc).
2. Checkout and build Super Heroes:

```sh
git clone https://github.com/quarkusio/quarkus-workshops
cd quarkus-workshops/quarkus-workshop-super-heroes
./mvnw clean package -DskipTests -Pcomplete
```

3. Run the infrastructure:

```sh
docker-compose -f super-heroes/infrastructure/docker-compose.yaml up -d
```

4. Start the UI

```sh
$JAVA_HOME/bin/java -jar super-heroes/ui-super-heroes/target/quarkus-app/quarkus-run.jar
```

5. In individual consoles start the microservices

```sh
$JAVA_HOME/bin/java -XX:CRaCCheckpointTo=/tmp/heroes -jar super-heroes/rest-heroes/target/quarkus-app/quarkus-run.jar 
$JAVA_HOME/bin/java -XX:CRaCCheckpointTo=/tmp/villains -jar super-heroes/rest-villains/target/quarkus-app/quarkus-run.jar
$JAVA_HOME/bin/java -XX:CRaCCheckpointTo=/tmp/fights \
  -Dquarkus.http.cors.origins='*' \
  -Dcom.arjuna.ats.internal.arjuna.utils.processImplementation=com.arjuna.ats.internal.arjuna.utils.UuidProcessId \ 
  -jar super-heroes/rest-fights/target/quarkus-app/quarkus-run.jar
```

Note that the property selecting Arjuna's `processImplementation` is not necessary at this point; we'll need that later, though.

6. Open http://localhost:8080, click on 'New fighters' and 'Fight' a few times.

It seems that there is a bug in the original application: the first request usually fails due to a timeout. This is unrelated to CRaC, and since subsequent requests usually succeed we can just reload the site (Ctrl+F5 in most browsers) and see that the application works correctly.

7. Checkpoint the three microservices:

```sh
for pid in $(jps -l | grep super-heroes/rest- | cut -f 1 -d ' '); do jcmd $pid JDK.checkpoint; done;
```

CRaC will experience some problems due to files or network connection being open:

```sh
1586473:
An exception during a checkpoint operation:
jdk.crac.CheckpointException
	at java.base/jdk.crac.Core.checkpointRestore1(Core.java:182)
	at java.base/jdk.crac.Core.checkpointRestore(Core.java:287)
	at java.base/jdk.crac.Core.checkpointRestoreInternal(Core.java:303)
	Suppressed: jdk.crac.impl.CheckpointOpenSocketException: tcp6 localAddr ::ffff:127.0.0.1 localPort 48768 remoteAddr ::ffff:127.0.0.1 remotePort 5432
		at java.base/jdk.crac.Core.translateJVMExceptions(Core.java:120)
		at java.base/jdk.crac.Core.checkpointRestore1(Core.java:186)
		... 2 more
1586666:
CR: Checkpoint ...
1586548:
An exception during a checkpoint operation:
jdk.crac.CheckpointException
	at java.base/jdk.crac.Core.checkpointRestore1(Core.java:122)
	at java.base/jdk.crac.Core.checkpointRestore(Core.java:246)
	at java.base/jdk.crac.Core.checkpointRestoreInternal(Core.java:262)
	Suppressed: java.nio.channels.IllegalSelectorException
		at java.base/sun.nio.ch.EPollSelectorImpl.beforeCheckpoint(EPollSelectorImpl.java:384)
		at java.base/jdk.crac.impl.AbstractContextImpl.beforeCheckpoint(AbstractContextImpl.java:66)
		at java.base/jdk.crac.impl.AbstractContextImpl.beforeCheckpoint(AbstractContextImpl.java:66)
		at java.base/jdk.crac.Core.checkpointRestore1(Core.java:120)
		... 2 more
	Suppressed: jdk.crac.impl.CheckpointOpenSocketException: tcp6 localAddr ::ffff:127.0.0.1 localPort 51778 remoteAddr ::ffff:127.0.0.1 remotePort 9092
		at java.base/jdk.crac.Core.translateJVMExceptions(Core.java:91)
		at java.base/jdk.crac.Core.checkpointRestore1(Core.java:145)
		... 2 more
	Suppressed: jdk.crac.impl.CheckpointOpenSocketException: tcp6 localAddr ::ffff:127.0.0.1 localPort 52200 remoteAddr ::ffff:127.0.0.1 remotePort 5432
		at java.base/jdk.crac.Core.translateJVMExceptions(Core.java:91)
		at java.base/jdk.crac.Core.checkpointRestore1(Core.java:145)
		... 2 more
	Suppressed: jdk.crac.impl.CheckpointOpenResourceException: anon_inode:[eventpoll]
		at java.base/jdk.crac.Core.translateJVMExceptions(Core.java:97)
		at java.base/jdk.crac.Core.checkpointRestore1(Core.java:145)
		... 2 more
	Suppressed: jdk.crac.impl.CheckpointOpenResourceException: anon_inode:[eventfd]
		at java.base/jdk.crac.Core.translateJVMExceptions(Core.java:97)
		at java.base/jdk.crac.Core.checkpointRestore1(Core.java:145)
		... 2 more
	Suppressed: jdk.crac.impl.CheckpointOpenSocketException: tcp6 localAddr ::ffff:127.0.0.1 localPort 58142 remoteAddr ::ffff:127.0.0.1 remotePort 9092
		at java.base/jdk.crac.Core.translateJVMExceptions(Core.java:91)
		at java.base/jdk.crac.Core.checkpointRestore1(Core.java:145)
		... 2 more
```

In a framework like Quarkus it is not up to the application to handle this, framework should listen to CRaC notifications and close/reopen them. This guide won't describe how these problems can be identified and fixed, please see [debugging guide](debugging.md) for that. Instead we will use version of dependencies that has these issues handled.

## Replacing CRaC non-compatible artifacts

The vanilla version of Quarkus Super Heroes relies on artifacts that do not handle checkpoint
and this would fail due to open files or sockets. Until CRaC becomes mainstream and these
libraries handle notifications we provide a CRaC-ed version with some of the problems fixed.

In order to identify these dependencies before running into errors we have created a Maven Enforcer
rule that can be included in the build and highlights the incompatible artifacts:

```xml
<build>
    <plugins>
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-enforcer-plugin</artifactId>
            <version>3.3.0</version>
            <dependencies>
                <dependency>
                    <groupId>io.github.crac</groupId>
                    <artifactId>crac-enforcer-rule</artifactId>
                    <version>1.0.0</version>
                </dependency>
            </dependencies>
            <executions>
                <execution>
                    <goals>
                        <goal>enforce</goal>
                    </goals>
                </execution>
            </executions>
            <configuration>
                <rules>
                    <cracDependencies />
                </rules>
            </configuration>
        </plugin>
    </plugins>
</build>
```

Now when you try to build the project, the enforcer will spit out errors, including suggestions
for a replacement artifact:

```sh
[ERROR] Failed to execute goal org.apache.maven.plugins:maven-enforcer-plugin:3.3.0:enforce (default) on project rest-villains: 
[ERROR] Rule 0: io.github.crac.CracDependencies failed with message:
[ERROR] io.quarkus.workshop.super-heroes:rest-villains:jar:1.0.0-SNAPSHOT
[ERROR]    io.quarkus:quarkus-resteasy-reactive:jar:2.15.3.Final
[ERROR]       io.quarkus.resteasy.reactive:resteasy-reactive-vertx:jar:2.15.3.Final
[ERROR]          io.vertx:vertx-web:jar:4.3.6
[ERROR]             io.vertx:vertx-web-common:jar:4.3.6
[ERROR]                io.vertx:vertx-core:jar:4.3.6 <--- replace with io.github.crac.io.vertx:vertx-core:4.3.8.CRAC.0
[ERROR]             io.vertx:vertx-auth-common:jar:4.3.6
[ERROR]                io.vertx:vertx-core:jar:4.3.6 <--- replace with io.github.crac.io.vertx:vertx-core:4.3.8.CRAC.0
[ERROR]             io.vertx:vertx-bridge-common:jar:4.3.6
[ERROR]                io.vertx:vertx-core:jar:4.3.6 <--- replace with io.github.crac.io.vertx:vertx-core:4.3.8.CRAC.0
[ERROR]             io.vertx:vertx-core:jar:4.3.6 <--- replace with io.github.crac.io.vertx:vertx-core:4.3.8.CRAC.0
[ERROR]          io.smallrye.reactive:smallrye-mutiny-vertx-core:jar:2.29.0
[ERROR]             io.smallrye.reactive:smallrye-mutiny-vertx-runtime:jar:2.29.0
[ERROR]                io.vertx:vertx-core:jar:4.3.6 <--- replace with io.github.crac.io.vertx:vertx-core:4.3.8.CRAC.0
[ERROR]             io.vertx:vertx-core:jar:4.3.6 <--- replace with io.github.crac.io.vertx:vertx-core:4.3.8.CRAC.0
[ERROR]       io.quarkus:quarkus-vertx-http:jar:2.15.3.Final
[ERROR]          io.smallrye.common:smallrye-common-vertx-context:jar:1.13.2
[ERROR]             io.vertx:vertx-core:jar:4.3.6 <--- replace with io.github.crac.io.vertx:vertx-core:4.3.8.CRAC.0
[ERROR]          io.smallrye.reactive:smallrye-mutiny-vertx-web:jar:2.29.0
[ERROR]             io.smallrye.reactive:smallrye-mutiny-vertx-uri-template:jar:2.29.0
[ERROR]                io.vertx:vertx-uri-template:jar:4.3.6
[ERROR]                   io.vertx:vertx-core:jar:4.3.6 <--- replace with io.github.crac.io.vertx:vertx-core:4.3.8.CRAC.0
[ERROR]    io.quarkus:quarkus-hibernate-orm-panache:jar:2.15.3.Final
[ERROR]       io.quarkus:quarkus-hibernate-orm:jar:2.15.3.Final
[ERROR]          io.quarkus:quarkus-agroal:jar:2.15.3.Final
[ERROR]             io.agroal:agroal-pool:jar:1.16 <--- replace with io.github.crac.io.agroal:agroal-pool:1.18.CRAC.0
```

The offending dependencies can be removed using `<exclusions>`, and CRaC'ed dependencies should be added.
Usually these have `groupId` prefixed with `org.github.crac.`, `artifactId` is identical and version is suffixed
with `.CRAC.N` where `N` stands for counter of CRaC-related changes; these should be added on top of the original (tagged) version.

```xml
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-resteasy-reactive</artifactId>
  <exclusions>
    <exclusion>
      <groupId>io.vertx</groupId>
      <artifactId>vertx-core</artifactId>
    </exclusion>
  </exclusions>
</dependency>
<dependency>
  <groupId>io.github.crac.io.vertx</groupId>
  <artifactId>vertx-core</artifactId>
  <version>4.3.8.CRAC.0</version>
</dependency>
```

It's likely that there won't be a CRaC'ed version exactly matching the original version; please test
for any compatibility issues thoroughly.

To see the 'patched' version please see [this fork](https://github.com/rvansa/quarkus-workshops/tree/crac).
To use the Maven Enforcer conveniently we have added a parent module to the microservices and set up Maven Enforcer.

```sh
git remote add rvansa https://github.com/rvansa/quarkus-workshops.git
git fetch rvansa crac && checkout rvansa/crac
```

## Runnning the patched version

1. Make sure that the non-patched version of the microservices is not running anymore, e.g. using Ctrl+C in console. 

2. Rebuild the patched microservices using `./mvnw clean package -DskipTests -Pcomplete`
 
3. Repeat steps 5 - 7 from the previous attempt, starting the apps, issuing a few requests through UI and performing the checkpoint.

The checkpoint might fail for some services: In this scenario Quarkus loads some classes during checkpoint
(e.g. from finalizers or when closing connections), opening some files. This may happen after the code that
was supposed to close all cached open files has executed, and leads to checkpoint failure.
If this is the case please trigger checkpoint again; this time everything should be loaded and the checkpoint should succeed. 

4. Restore the services in individual consoles:

```sh
$JAVA_HOME/bin/java -jar -XX:CRaCRestoreFrom=/tmp/heroes
$JAVA_HOME/bin/java -jar -XX:CRaCRestoreFrom=/tmp/villains
$JAVA_HOME/bin/java -jar -XX:CRaCRestoreFrom=/tmp/fights
```

5. Go to http://localhost:8080 and try to click through the UI few times. You can check consoles to see that everything works.

Side note: The Super Heroes workshop includes one more microservice, the `event-statistics`. This microservice hasn't been CRaC'ed yet
as it requires some additional fixes in Kafka.
