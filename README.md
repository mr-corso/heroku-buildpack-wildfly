# Heroku Wildfly Buildpack

This is a [Heroku Buildpack](https://devcenter.heroku.com/articles/buildpacks)
for running [Wildfly AS](http://wildfly.org).

## Usage

Put your WAR file(s) in `target/` and deploy.

### Using with the Java buildpack

You can use the standard Heroku Java buildpack to compile your WAR file, and
then have WildFly run it:

```bash
$ heroku buildpacks:clear
$ heroku buildpacks:add heroku/java
$ heroku buildpacks:add https://github.com/mortenterhart/heroku-buildpack-wildfly
```

Then deploy your Maven project with a `pom.xml`, Heroku will run the Java buildpack
to compile it, and as long as you output a `target/*.war` file the Wildfly buildpack
will deploy and run it on a Wildfly standalone instance.

The location of the Wildfly server is stored in the `$JBOSS_HOME` environment
variable.

### Configuring the Wildfly version

You can configure the Wildfly version by creating a file called `system.properties`
in the root directory of your project and setting the property `wildfly.version`.

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
-----> Using WildFly version 16.0.0.Final
-----> Installing WildFly 16.0.0.Final ...
...
```

## Default Process type

If your project doesn't contain a `Procfile`, it is automatically created by the
Wildfly buildpack with the following process type:

```yaml
web: $JBOSS_HOME/bin/standalone.sh -b 0.0.0.0 -Djboss.http.port=$PORT
```
