+++
title = "Coordinated Restore at Checkpoint"
weight = 1
+++

{{% notice style="blue" title="What is CRaC?" icon="java" %}}
Coordinated Restore at Checkpoint (CRaC) is a JDK project that allows you to start Java programs with a shorter time to first transaction, combined with less time and resources to achieve full code speed.
{{% /notice %}}

<div style="text-align: center">

{{% button href="/use/implement-crac/" style="blue" icon="fas fa-github" %}}CRaC IN YOUR CODE{{% /button %}}
{{% button href="/use/checkpoint-and-restore/" style="blue" icon="rocket" %}}USING CRaC{{% /button %}}

{{% button href="https://github.com/CRaC/org.crac/tags" style="blue" icon="bookmark" %}}CRaC API 1.4.0 NOW AVAILABLE{{% /button %}}

## Why CRaC?

The CRaC (Coordinated Restore at Checkpoint) Project researches the coordination of Java programs with mechanisms to checkpoint (make an image of, snapshot) a Java instance while executing. Restoring from the image could solve some of the problems with the start-up and warm-up times. The primary aim of the Project is to develop a new standard mechanism-agnostic API to notify Java programs about the checkpoint and restore events. Other research activities will include, but will not be limited to, integration with existing checkpoint/restore mechanisms and development of new ones, changes to JVM and JDK to make images smaller and ensure they are correct.

## USED BY

<div style="display: flex; justify-content: space-between;">

<span style="border: solid 1px black; padding: 10px; margin: 10px; flex-grow: 1; text-align: center;">
<img src="/images/logo/spring.png" height="50px" />
<span style="font-weight: bold; font-size: 1.4em;">Spring Boot</span>
<br/><br/>

{{% button href="https://github.com/CRaC/example-spring-boot" style="blue" icon="github" %}}Example project{{% /button %}}

[More info](/frameworks/spring-boot/)

</span>

<span style="border: solid 1px black; padding: 10px; margin: 10px; flex-grow: 1; text-align: center;">
<img src="/images/logo/quarkus.svg" height="50px" />
<span style="font-weight: bold; font-size: 1.4em;">Quarkus</span>
<br/><br/>

{{% button href="https://github.com/CRaC/example-quarkus" style="blue" icon="github" %}}Example project{{% /button %}}

[More info](/frameworks/quarkus/)

</span>

<span style="border: solid 1px black; padding: 10px; margin: 10px; flex-grow: 1; text-align: center;">
<img src="/images/logo/micronaut.webp" height="50px" />
<span style="font-weight: bold; font-size: 1.4em;">Micronaut</span>
<br/><br/>

{{% button href="https://github.com/CRaC/example-micronaut" style="blue" icon="git" %}}Example project{{% /button %}}

[More info](/frameworks/micronaut/)

</span>

<span style="border: solid 1px black; padding: 10px; margin: 10px; flex-grow: 1; text-align: center;">
<img src="/images/logo/aws-lambda.webp" height="50px" />
<span style="font-weight: bold; font-size: 1.4em;">AWS Lambda</span>
<br/><br/>

{{% button href="https://github.com/CRaC/example-lambda" style="blue" icon="github" %}}Example project{{% /button %}}

[More info](/frameworks/aws-lambda/)

</span>
</div>

## Features

<div style="display: flex; justify-content: space-between;">

<span style="border: solid 1px black; padding: 10px; margin: 10px; flex-grow: 1; text-align: center;">
<span style="font-weight: bold; font-size: 1.4em;">Super fast startup</span>
<br/><br/>
Startup within milliseconds from a checkpoint.
</span>

<span style="border: solid 1px black; padding: 10px; margin: 10px; flex-grow: 1; text-align: center;">
<span style="font-weight: bold; font-size: 1.4em;">Checkpoint creation</span>
<br/><br/>
Generate checkpoints from code or with jcmd.
</span>

<span style="border: solid 1px black; padding: 10px; margin: 10px; flex-grow: 1; text-align: center;">
<span style="font-weight: bold; font-size: 1.4em;">Restore from checkpoint</span>
<br/><br/>
Restore on the same machine, or many others from a checkpoint.

</div>

<div style="display: flex; justify-content: space-between;">

<span style="border: solid 1px black; padding: 10px; margin: 10px; flex-grow: 1; text-align: center;">
<span style="font-weight: bold; font-size: 1.4em;">Minimal code changes</span>
<br/><br/>
Use frameworks, or implement the CRaC API to assist in the creation and restore of checkpoints
</span>

<span style="border: solid 1px black; padding: 10px; margin: 10px; flex-grow: 1; text-align: center;">
<span style="font-weight: bold; font-size: 1.4em;">Framework support</span>
<br/><br/>
Several frameworks (Spring Boot, Quarkus, Micronaut,...) offer CRaC support out-of-the-box.
</span>

<span style="border: solid 1px black; padding: 10px; margin: 10px; flex-grow: 1; text-align: center;">
<span style="font-weight: bold; font-size: 1.4em;">Use it in the Cloud</span>
<br/><br/>
AWS Lambda has CRaC functionality integrated, no code changes needed!
</span>

</div>

</div>