# Heroku WildFly Buildpack

[![Travis Build Status](https://travis-ci.com/mortenterhart/heroku-buildpack-wildfly.svg?branch=master)][travis-status]
[![Heroku Elements](https://img.shields.io/badge/Heroku_Elements-published-6762A6)][heroku-elements]
[![Buildpack Registry](https://img.shields.io/badge/Buildpack_Registry-mterhart/wildfly-6762A6)][buildpack-registry]
[![Latest GitHub Release](https://img.shields.io/github/v/tag/mortenterhart/heroku-buildpack-wildfly?color=blue&label=Latest%20Release&logo=github)][github-releases]

[travis-status]: https://travis-ci.com/mortenterhart/heroku-buildpack-wildfly "View Travis Build Status"
[heroku-elements]: https://elements.heroku.com/buildpacks/mortenterhart/heroku-buildpack-wildfly "Buildpack on Heroku Elements"
[buildpack-registry]: https://devcenter.heroku.com/articles/buildpack-registry "Buildpack Registry"
[github-releases]: https://github.com/mortenterhart/heroku-buildpack-wildfly/releases "GitHub Releases"

This is a [Heroku Buildpack](https://devcenter.heroku.com/articles/buildpacks)
for running the [WildFly Application Server](http://wildfly.org) on Heroku.

If you are experiencing troubles with this buildpack or the WildFly server,
please see the [Troubleshooting](#troubleshooting) section below first and
otherwise file an issue.

## Standalone Usage

Put your WAR file(s) in `target/` and deploy.

### Using with the Java buildpack

You can use the standard Heroku Java buildpack to compile your WAR file, and
then have WildFly run it:

```bash
heroku buildpacks:clear
heroku buildpacks:add heroku/java
heroku buildpacks:add mterhart/wildfly
```

Then deploy your Maven project with a `pom.xml`, Heroku will run the Java buildpack
to compile it, and as long as you output a `target/*.war` file the Wildfly buildpack
will deploy and run it on a Wildfly standalone instance.

The location of the Wildfly server is stored in the `$JBOSS_HOME` environment
variable.

### Creating a Heroku app with this Buildpack

The `mterhart/wildfly` identifier will always pick the latest published version
of this buildpack which is recommended to use. You can directly create a new
Heroku application using the latest version with this command:

```bash
heroku create --buildpack mterhart/wildfly
```

### Specifying an older Revision of the Buildpack

If you want to stick to a specific revision of this buildpack, you can use the
buildpack URL along with a tag. For example, if you pick the tag `v3` you need
to append it to the URL when adding to your application:

```bash
heroku buildpacks:add https://github.com/mortenterhart/heroku-buildpack-wildfly#v3
```

## Usage from a Buildpack

This buildpack is designed to be used from within other buildpacks. The following
code downloads and sources the buildpack:

```bash
WILDFLY_BUILDPACK_URL="https://buildpack-registry.s3.amazonaws.com/buildpacks/mterhart/wildfly.tgz"
mkdir -p /tmp/wildfly-buildpack
curl --retry 3 --silent --location "${WILDFLY_BUILDPACK_URL}" | tar xzm -C /tmp/wildfly-buildpack --strip-components=1

source /tmp/wildfly-buildpack/lib/wildfly.sh
```

All buildpack functionalities are now present to the current context. See the
`lib/wildfly.sh` script for all features offered by this buildpack.

### Specifying a specific Revision of the Buildpack

You can use another revision of this buildpack for your own one. Simply change the
buildpack URL and append a version specifier to the filename, for example `v10`.
Then change the line in your script to the following:

```bash
WILDFLY_BUILDPACK_URL="https://buildpack-registry.s3.amazonaws.com/buildpacks/mterhart/wildfly-v10.tgz"
```

## Configuration

### Config Vars

|     **Name**      | **Default Value** | **Description** |
| :---------------: | :---------------: | :-------------- |
| `BUILDPACK_DEBUG` |      `false`      | When set to `true` the buildpack will produce more output including executed commands, values of variables and time measurements. **Warning**: This option should only be used for testing your build and not for production. It is possible that sensitive data gets printed to the logs. |

### Configuring the Wildfly version

You can configure the Wildfly version by creating a file called `system.properties`
in the root directory of your project and setting the property `wildfly.version`.
The version has to be one of the defined ones from <https://wildfly.org/downloads>.

```properties
wildfly.version=16.0.0.Final
```

The buildpack will then download the appropriate Wildfly version and install
it to the preferred location. The version is stored inside the `$WILDFLY_VERSION`
environment variable.

Example:

```bash
$ ls
Procfile pom.xml src

$ echo "wildfly.version=16.0.0.Final" > system.properties

$ git add system.properties && git commit -m "Configure Wildfly 16"

$ git push heroku master
...
-----> Java app detected
...
-----> WildFly app detected
-----> Using provided JDK
...
-----> Installing WildFly 16.0.0.Final...
...
```

### Default Process type

If your project doesn't contain a `Procfile`, it is automatically created by the
Wildfly buildpack with the following process type:

```yaml
web: ${JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0 -Djboss.http.port=$PORT
```

## Troubleshooting

### `Could not load Logmanager "org.jboss.logmanager.LogManager"`

If you came across the error messages shown below in your log you might have
activated the [Heroku Exec](https://devcenter.heroku.com/articles/exec) feature
which enables an SSH access to your dyno. This is a known issue with this feature
causing the WildFly server to crash right after startup.

```txt
Could not load Logmanager "org.jboss.logmanager.LogManager"
java.lang.ClassNotFoundException: org.jboss.logmanager.LogManager
    at ...

WARNING: Failed to load the specified log manager class org.jboss.logmanager.LogManager

ERROR: WFLYCTL0013: Operation ("parallel-extension-add") failed - address: ([])
java.lang.RuntimeException: WFLYCTL0079: Failed initializing module org.jboss.as.logging
Caused by: java.util.concurrent.ExecutionException: java.lang.IllegalStateException: WFLYLOG0078: The logging subsystem requires the log manager to be org.jboss.logmanager.LogManager. The subsystem has not be initialized and cannot be used. To use JBoss Log Manager you must add the system property "java.util.logging.manager" and set it to "org.jboss.logmanager.LogManager"
```

The Heroku Exec feature modifies the [`JAVA_TOOL_OPTIONS`][java-tool-options]
environment variable that provides additional Java command-line options to the
Java process. This is probably due to the Java diagnostic tools that the Exec
feature provisions. The Exec feature adds the following command-line options
to the environment variable (as shown from the log):

```diff
Picked up JAVA_TOOL_OPTIONS:
  -XX:+UseContainerSupport
  -Xmx300m
  -Xss512k
  -XX:CICompilerCount=2
  -Dfile.encoding=UTF-8
+ -Dcom.sun.management.jmxremote
+ -Dcom.sun.management.jmxremote.port=1098
+ -Dcom.sun.management.jmxremote.rmi.port=1099
+ -Dcom.sun.management.jmxremote.ssl=false
+ -Dcom.sun.management.jmxremote.authenticate=false
+ -Dcom.sun.management.jmxremote.local.only=true
+ -Djava.rmi.server.hostname=172.17.45.138
+ -Djava.rmi.server.port=1099
  -Djava.util.logging.manager=org.jboss.logmanager.LogManager  # added by this buildpack
```

More information about the `JAVA_TOOL_OPTIONS` environment variable can be
obtained at <https://docs.oracle.com/javase/8/docs/technotes/guides/troubleshoot/envvars002.html>.

These additional options cause the WildFly server to crash during startup. You
can easily check if you have activated the Heroku Exec feature by looking for
the following in your log:

```txt
heroku[web.1]: Starting process with command `$JBOSS_HOME/bin/standalone.sh -b 0.0.0.0 -Djboss.http.port=17971`
app[web.1]: [heroku-exec] Starting
```

The issue can be resolved by disabling the Heroku Exec feature using the
following command:

```txt
heroku features:disable runtime-heroku-exec
```

If you have an app in a private space you also need to remove the Heroku Exec
buildpack:

```txt
heroku buildpacks:remove heroku/exec
```

[java-tool-options]: https://docs.oracle.com/javase/8/docs/technotes/guides/troubleshoot/envvars002.html "More information on JAVA_TOOL_OPTIONS"
