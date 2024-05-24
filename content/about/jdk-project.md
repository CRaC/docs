+++
title = "OpenJDK CRaC Project"
weight = 13
+++

OpenJDK CRaC Project is developed in https://github.com/openjdk/crac.

Latest release can be found in https://crac.github.io/openjdk-builds.

```sh
$ sudo tar zxf <jdk>.tar.gz
```

**NOTE**: The JDK archive should be extracted with `sudo`.

When using CRaC, if you see an "Operation not permitted" error, you may have to update your `criu` permissions with:

```sh
sudo chown root:root $JAVA_HOME/lib/criu
sudo chmod u+s $JAVA_HOME/lib/criu
```

