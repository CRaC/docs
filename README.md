# C/RaC
Checkpoint/Restore-at-Checkpoint is OpenJDK feature that provides rapid start of warmed-up java application.
The application started as usual, warmed-up and then image of JVM and the application are stored ("checkpointed") to a storage.
After that the image used to start java app instances which starts ("restored") at the point of checkpoint.

Not everything can be and is stored in the image: opened files, sockets remain to be external resources.
C/RaC requires all external resources to be released before checkpoint, so they need to be re-aqcuired after restore.
A notification service is provided for applications to release and acquire resources.

## Results

## API

The JDK provides an API in for notification described in [jdk/api]

### org.crac

[jdk](https://github.com/org-crac/jdk) provides a proof-of-concept C/RaC API implementation for Linux as well as prebuilt binaries.

[org.crac](https://github.com/org-crac/org.crac) compatibility wrapper provides a C/RaC-aware application run on any Java8+ implementation 
It wraps native C/RaC implementaion in JDK and provide dummy implementaiton if native one is unavailble. 

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

Current OpenJDK implementaion is based on using CRIU project to create the image.
[CRIU](https://github.com/org-crac/criu) hosts few changes made mainline CRIU to improve C/RaC usability.

