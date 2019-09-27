# Heroku Wildfly Buildpack

[![Heroku Elements](https://img.shields.io/badge/Heroku_Elements-published-6762A6)][heroku-elements]
[![Buildpack Registry](https://img.shields.io/badge/Buildpack_Registry-mterhart/wildfly-6762A6)][buildpack-registry]
[![Latest GitHub Tag](https://img.shields.io/github/v/tag/mortenterhart/heroku-buildpack-wildfly?color=blue&label=Latest%20Version&logo=github)][github-tags]

[heroku-elements]: https://elements.heroku.com/buildpacks/mortenterhart/heroku-buildpack-wildfly "Buildpack on Heroku Elements"
[buildpack-registry]: https://devcenter.heroku.com/articles/buildpack-registry "Buildpack Registry"
[github-tags]: https://github.com/mortenterhart/heroku-buildpack-wildfly/tags "Latest GitHub Tags"

This is a [Heroku Buildpack](https://devcenter.heroku.com/articles/buildpacks)
for running the [Wildfly Application Server](http://wildfly.org) on Heroku.

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

## Configuration

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
