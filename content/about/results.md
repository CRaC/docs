+++
title = "Startup Improvement Results"
weight = 12
+++

CRaC support was implemented in a few frameworks with the following results.
The source code can be found in the [Projects with CRaC support](#projects-with-crac-support) section.

<details><summary>The environment</summary>
<p>

* laptop with Intel i7-5500U, 16Gb RAM and SSD.
* Linux kernel 5.7.4-arch1-1
* data was collected in container running `ubuntu:18.04` based image
* host operating system: archlinux

[jdk14-crac build](https://github.com/org-crac/jdk/releases/tag/release-jdk-crac)

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

You need to build examples according to the [Projects with CRaC support](#projects-with-crac-support) section.

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

![Startup Time](/images/results/startup.png)

![Spring Boot](/images/results/spring-boot.png)

![Quarkus](/images/results/quarkus.png)

![Micronaut](/images/results/micronaut.png)

![xml-transform](/images/results/xml-transform.png)

