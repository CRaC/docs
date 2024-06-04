+++
title = "Use CRaC"
weight = 13
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

## Read more

{{% children sort="weight" %}}