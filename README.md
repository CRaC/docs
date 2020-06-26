# C/RaC

Checkpoint/Restore-at-Checkpoint is an OpenJDK feature that provides a fast start of warmed-up java application.
At first, the image of JVM and an application in the warmed-up state need to be prepared.
For the preparational step, an application is started as usual and warmed up, then the image of the JVM and the application is stored ("checkpointed") to storage
After that, the image used to start java app instances that are started ("restored") at the point of the checkpoint.

Not everything can be and is stored in the image: open files, sockets remain to be external resources.
C/RaC requires all external resources to be released before the checkpoint, so they need to be re-acquired after restore.
A notification service is provided for applications to release and acquire resources.

## Results

(Preliminary results from https://github.com/org-crac/example-spring-boot/runs/788817292)

![Startup Time](startup.png)

![Spring Boot](spring-boot.png)

## API

The JDK notification service provided via this [API](https://org-crac.github.io/jdk/jdk-crac/api/java.base/jdk/crac/package-summary.html).

### org.crac

[jdk](https://github.com/org-crac/jdk) provides a proof-of-concept C/RaC API implementation for Linux as well as prebuilt binaries.

[org.crac](https://github.com/org-crac/org.crac) compatibility wrapper allows a C/RaC-aware application to run on any Java8+ implementation.
It wraps native C/RaC implementation in JDK and provides dummy implementation if native one is unavailable. 

## Examples

There are a few third-party frameworks and libraries in this GitHub organization which demonstrates how C/RaC support is implemented.

* [Tomcat](https://github.com/org-crac/tomcat)
* [Quarkus](https://github.com/org-crac/quarkus)
* [Micronaut](https://github.com/org-crac/micronaut-core)

C/RaC support in frameworks allows users to slightly if at all modify their services to benefit from C/RaC.

* [example-spring-boot](https://github.com/org-crac/example-spring-boot)
* [example-quarkus](https://github.com/org-crac/example-quarkus)
* [example-micronaut](https://github.com/org-crac/example-micronaut)

## Implementation

Current OpenJDK implementation is based on using the CRIU project to create the image.

[CRIU](https://github.com/org-crac/criu) hosts a few changes made to improve C/RaC usability.

