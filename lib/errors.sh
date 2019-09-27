#!/usr/bin/env bash

# Writes a formatted error message provided on stdin to the standard
# output and exits with an status of 1. If no input is provided on the
# stdin channel the function produces an error itself.
#
# Input:
#   stdin:  the error message
#
# Returns
#   stdout: the resulting error message
#   exit code: 1
write_error() {
    if [ -t 0 ]; then
        error "Error message on stdin expected. Use a heredoc to write it."
    fi

    # We need to use the 'true' command here since 'read' exits with 1
    # when it encounters EOF. The delimiter is unset here so that 'read'
    # obtains the complete input including all lines and sets it to the
    # command variable. The 'true' command is important for scripts
    # using 'set -e' like the buildpack's compile script so that they
    # don't abort execution on the exit code 1 (see also
    # https://stackoverflow.com/a/15422165). The 'set -e' option is
    # responsible for exiting the shell if a command exits with a non-zero
    # exit status.
    local errorMessage
    read -r -d '' errorMessage || true

    error_return "${errorMessage}"
}

# Error on an unsupported WildFly version, i.e. a version not available.
#
# Params:
#   $1:  wildflyVersion  The unsupported WildFly version
#   $2:  defaultVersion  The buildpack's default WildFly version
#
# Returns:
#   always 1
error_unsupported_wildfly_version() {
    local wildflyVersion="$1"
    local defaultVersion="$2"

    write_error <<ERROR
Unsupported WildFly version: ${wildflyVersion}

Please check your system.properties file to ensure wildfly.version
is one of the defined versions from https://wildfly.org/downloads.

You can also remove the system.properties file to install the default
version ${defaultVersion}.
ERROR
}

# Error on unavailable WAR files in the 'target' directory
#
# Returns:
#   always 1
error_no_war_files_found() {
    write_error <<ERROR
No WAR files found in 'target' directory.

Please ensure your Maven build configuration in the pom.xml is creating
the necessary WAR file(s) for your application under the target/ directory.

For help on the usage of the 'maven-war-plugin' visit
https://maven.apache.org/plugins/maven-war-plugin/usage.html.
ERROR
}
