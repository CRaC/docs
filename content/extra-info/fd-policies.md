+++
title = "File descriptor policies"
weight = 40
+++

CRaC requires that the application closes all open files, network connections etc. - on Linux these are represented as file descriptors. However, it might be difficult to alter the application to properly coordinate with the checkpoint, e.g. due to a code in a library you cannot modify. In those cases CRaC offers a limited handling via configuration. Note that this applies only to file descriptors opened through JDK API; anything opened through native code cannot be handled this way.

The configuration is set up by pointing system property `jdk.crac.resource-policies` to a file that consists of several rules separated by three dashes (`---`). Lines starting with hash sign (`#`) are ignored. Each rule consists of several `key: value` pairs. The above is actually a subset of YAML format, so we suggest that you use the `.yaml` or `.yml` extension for convenient use in an editor. See an example of this file:

```sh
type: file
path: /path/to/my/file
action: close
---
# Here is some comment
type: FILE
path: **/*.log
action: reopen
```

Each rule has two mandatory properties: `type` and `action`, with case-insensitive values. Available types are:

* `file`: a file (or directory) on a local filesystem
* `pipe`: an anonymous pipe - named pipes are handled using the type `file`
* `socket`: network (TCP, UDP, ...) or unix socket
* `filedescriptor`: raw file descriptor that cannot be identified by any of the above

The order of rules in the file is important; for each file descriptor found open the first matching rule will be applied, any subsequent rules are ignored.

## Files

As the first example shows, files can be selected using the `path` property. This supports 'glob' pattern matching - see `java.nio.file.FileSystem.getPathMatcher()` javadoc for detailed usage.
These are the possible actions:

* `error`: The default action, just print error and fail the checkpoint.
* `ignore`: Leave handling of the open file to C/R engine (CRIU). This will likely validate and reopen the file on restore.
* `close`: Close the file. An attempt to use it after restore will fail with runtime exception.
* `reopen`: Close the file, and try reopen it (on the same position) after restore.

Unless the action is `error`, any file found open will trigger a warning to be printed to the logging system. This can be suppressed with `warn: false` property.

## Pipes

Anonymous pipes don't have any means to identify, therefore it makes sense to have at most one rule for these. Available actions are `error`, `ignore` and `close` with the same meaning as in case of files.

## Sockets

The rule can be refined using one of these properties:

* `family`: `ipv6` or `inet6` for IPv6 sockets, `ipv4` or `inet4` for IPv4 sockets, `ip` or `inet` for any IPv4/IPv6, `unix` for Unix domain sockets
* `localAddress` and `remoteAddress`: `*` could be used for any bound address
* `localPort` and `remotePort`: numeric port, `*` matches any port
* `localPath` and `remotePath`: for Unix sockets, supports 'glob' pattern matching

Actions `error`, `ignore` and `close` apply as in the previous cases. It is possible to use action `reopen`, too - this will close the socket before checkpoint, but the reopening part is not implemented, therefore will result in a runtime exception after restore. Eventually this will be implemented for listening sockets.

## Raw file descriptors

In some cases we might find that file descriptor was created without a matching higher-level object (e.g. `FileOutputStream`). Such descriptor can be identified either with its numeric value, using `value: 123`, or matching its native description: `regex: .*something.*` following the `java.util.regex.Pattern.compile()` syntax.

For raw descriptors, only the `error`, `ignore` and `close` actions are available.

