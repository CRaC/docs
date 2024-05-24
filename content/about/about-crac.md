+++
title = "What is Coordinated Restore at Checkpoint?"
weight = 11
+++

Coordinated Restore at Checkpoint (CRaC) is an OpenJDK feature that provides a fast start and immediate performance for Java applications.

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

With more Java frameworks and libraries adopting CRaC, applications can benefit with little or no changes in the code.
Moreover, the required amount of changes in the resource management code tends to be small, see examples below.

Coordinated Restore is not tied to a particular checkpoint/restore implementation and will able to use existing ones (CRIU, docker checkpoint/restore) and ones yet to be developed.


### CPU Features

When running checkpoint and restore on different computers you may seen an error message during restore

```
You have to specify -XX:CPUFeatures=[...] together with -XX:CRaCCheckpointTo when making a checkpoint file; specified -XX:CRaCRestoreFrom file contains CPU features [...]; missing features of this CPU are [...]
```

See [more details about the CPU Features configuration](cpu-features.md).

## Programmer's flow

Programs may need to be adjusted for use with Coordinated Restore at Checkpoint.

A [step-by-step guide](STEP-BY-STEP.md) and [best practices guide](best-practices.md) provide information on how to implement the CRaC support in the code.

Another option is to use an existing framework with CRaC support.

No changes required:
* Micronaut: https://github.com/CRaC/example-micronaut
* Quarkus Hello World: https://github.com/CRaC/example-quarkus
* Spring Boot: https://github.com/CRaC/example-spring-boot

With configuration changes:
* [Quarkus Super Heroes migration](super-heroes.md) shows a walkthrough for making an existing non-trivial Quarkus application CRaC-able.

### API

The CRaC API is not a part of Java SE specification.
We hope that eventually it will be there, until then there are different packages that can be used.

#### `jdk.crac`

* [javadoc](https://crac.github.io/jdk/jdk-crac/api/java.base/jdk/crac/package-summary.html)

This is the API that is implemented in the [CRaC JDK](#JDK).

Please refer to [`org.crac`](#orgcrac) if you are looking to add CRaC support to a code that should also work on a regular JDK/JRE.

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


## Implementation details

Current OpenJDK implementation is based on using the CRIU project to create the image.

[CRIU](https://github.com/CRaC/criu) hosts a few changes made to improve CRaC usability.

You can read more about debugging C/R issues in your application in the [debug guide](./debugging.md).

## Workarounds

Sometimes it might be difficult to alter the application to properly coordinate with the checkpoint (e.g. due to a code in a library you cannot modify). As a temporary workaround you can [configure file-descriptor policies](./fd-policies.md).

