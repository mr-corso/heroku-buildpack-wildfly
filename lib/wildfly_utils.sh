#!/usr/bin/env bash
#
# This script provides useful utility functions for the WildFly installation
# on Heroku. It is used for the Heroku WildFly buildpack and can also be used
# by other scripts and buildpacks by downloading and sourcing this script. The
# JVM Common buildpack is loaded for various utility functions, but is only
# downloaded if it wasn't downloaded yet.
#
# The functions in this script can identify a WildFly version specified in the
# file 'system.properties', download the requested WildFly version and verify
# its SHA1 checksum, validate the download URL, install WildFly, deploy the
# WAR files previously built with the Heroku Java buildpack, create a default
# process configuration and export the environment variables for the WildFly.
#
# The download artifacts for the WildFly server are cached between builds in
# the CACHE_DIR argument that is provided to the 'bin/compile' script in order
# to speed up consecutive builds.
#
# When sourcing this script it is recommended to use 'set -e' to abort execution
# on any command exiting with a non-zero exit status so that execution will not
# continue on an error.
#
# shellcheck disable=SC1090,SC2155

DEFAULT_WILDFLY_VERSION="16.0.0.Final"

# Installs the WildFly server by downloading and caching the zip file and deploys
# the WAR files from the target/ folder to the server instance. It creates a
# default process configuration if none is provided and exports the home and
# version of the WildFly server inside environment variables.
#
# Params:
#   $1:  buildDir        The Heroku build directory
#   $2:  cacheDir        The Heroku cache directory
#   $3:  wildflyVersion  (optional) the WildFly version to download
#
# Returns:
#  0: The installation was successful
#  1: An error occured
install_wildfly() {
    local buildDir="$1"
    local cacheDir="$2"
    if [ ! -d "${buildDir}" ]; then
        error_return "Could not install WildFly: Build directory does not exist"
        return 1
    fi
    if [ ! -d "${cacheDir}" ]; then
        error_return "Could not install WildFly: Cache directory does not exist"
        return 1
    fi

    # Identify WildFly versions
    local wildflyVersion="${3:-$(detect_wildfly_version "${buildDir}")}"

    # Specify zip filename to download to
    local wildflyZip="wildfly-${wildflyVersion}.zip"

    # Download WildFly to cache if not already existing
    if [ ! -f "${cacheDir}/${wildflyZip}" ]; then
        download_wildfly "${wildflyVersion}" "${cacheDir}/${wildflyZip}"
    else
        status "Using WildFly ${wildflyVersion} from cache"
    fi

    status_pending "Installing WildFly ${wildflyVersion}"

    # Make a copy of the zip file
    cp "${cacheDir}/${wildflyZip}" "${buildDir}"

    # Remove the .jboss directory if it exists
    local jbossDir="${buildDir}/.jboss"
    if [ -d "${jbossDir}" ]; then
        rm -rf "${jbossDir}"
    fi

    # Create the .jboss directory
    mkdir -p "${jbossDir}"

    # Unzip the contents
    unzip -d "${jbossDir}" -q "${buildDir}/${wildflyZip}"
    rm -f "${buildDir}/${wildflyZip}"

    status_done

    # Export environment variables
    export JBOSS_HOME="${jbossDir}/wildfly-${wildflyVersion}"
    export JBOSS_CLI="${JBOSS_HOME}/bin/jboss-cli.sh"
    export WILDFLY_VERSION="${WILDFLY_VERSION:-${wildflyVersion}}"

    _deploy_war_files "${buildDir}" "${JBOSS_HOME}"
    _create_process_configuration "${buildDir}" "${JBOSS_HOME}" "${WILDFLY_VERSION}"
    _create_profile_script "${buildDir}" "${JBOSS_HOME}" "${JBOSS_CLI}" "${WILDFLY_VERSION}"
}

# Downloads a WildFly instance of a specified version to a specified location
# and verifies it SHA1 checksum. In addition, the URL for the passed version
# is validated for correctness.
#
# Params:
#   $1:  wildflyVersion  The version to download. Must be a defined version
#                        from https://wildfly.org/downloads.
#   $2:  targetFilename  The filename to which to write the zip file
#
# Returns:
#   0: The WildFly was downloaded successfully
#   1: There was a validation or SHA1 verification error
download_wildfly() {
    local wildflyVersion="$1"
    local targetFilename="$2"

    local wildflyUrl="$(_get_wildfly_download_url "${wildflyVersion}")"

    # Validate the url for the specific version
    if ! validate_wildfly_url "${wildflyUrl}" "${wildflyVersion}"; then
        return 1
    fi

    status_pending "Downloading WildFly ${wildflyVersion} to cache"
    curl --retry 3 --silent --location --output "${targetFilename}" "${wildflyUrl}"
    status_done

    # Verify the checksum
    status "Verifying SHA1 checksum"
    local wildflySHA1="$(curl --retry 3 --silent --location "${wildflyUrl}.sha1")"
    if ! verify_sha1_checksum "${wildflySHA1}" "${targetFilename}"; then
        return 1
    fi
}

# Detects the WildFly version from the 'system.properties' file or chooses
# the default version if this file does not exist.
#
# Params:
#   $1:  buildDir  The Heroku build directory
#
# Returns:
#   stdout: the detected WildFly version
detect_wildfly_version() {
    local buildDir="$1"

    if [ ! -d "${buildDir}" ]; then
        error_return "Could not detect WildFly version: Build directory does not exist"
        return 1
    fi

    local systemProperties="${buildDir}/system.properties"
    if [ -f "${systemProperties}" ]; then
        if sed -E '/^[[:blank:]]*\#/d' "${systemProperties}" | \
           grep -Eq "wildfly\.version[[:blank:]]*="; then
            local detectedVersion="$(sed -E '/^[[:blank:]]*\#/d' "${systemProperties}" | \
                grep -E "wildfly\.version[[:blank:]]*=[[:blank:]]*[A-Za-z0-9\.]+$" | \
                sed "s/^[^=]*=//")"
            if [ -n "${detectedVersion}" ]; then
                echo "${detectedVersion}"
            else
                echo "${DEFAULT_WILDFLY_VERSION}"
            fi
        else
            echo "${DEFAULT_WILDFLY_VERSION}"
        fi
    else
        echo "${DEFAULT_WILDFLY_VERSION}"
    fi
}

# Builds the WildFly download url for the specified version.
#
# Params:
#   $1:  wildflyVersion  The version to download
#
# Returns:
#   stdout: the download url
_get_wildfly_download_url() {
    local wildflyVersion="$1"

    local wildflyBaseUrl="https://download.jboss.org/wildfly"
    local wildflyDownloadUrl="${wildflyBaseUrl}/${wildflyVersion}/wildfly-${wildflyVersion}.zip"

    echo "${wildflyDownloadUrl}"
}

# Validates the built download url for WildFly by making a simple HTTP request
# and checking for status 200. If the request does not return a 200 code the
# version number is invalid.
#
# Params:
#   $1:  wildflyUrl      The WildFly download url
#   $2:  wildflyVersion  The WildFly version
#
# Returns:
#   0: The given url is a valid download url
#   1: The url is invalid because the specified version is not defined
validate_wildfly_url() {
    local wildflyUrl="$1"
    local wildflyVersion="$2"

    if [ "$(_get_url_status "${wildflyUrl}")" != "200" ]; then
        error_return "Unsupported WildFly version: ${wildflyVersion}
        
Please check your system.properties file to ensure wildfly.version
is one of the defined versions from https://wildfly.org/downloads.

You can also remove the system.properties file to install the default
version ${DEFAULT_WILDFLY_VERSION}."
        return 1
    fi
}

# Verifies the SHA-1 checksum that is provided for the WildFly zip file. The
# checksum needs to be downloaded from the WildFly download page and can be
# passed to this function in order to check it against the zip file.
#
# Params:
#   $1:  checksum  the downloaded SHA-1 checksum for the zip file
#   $2:  file      the path to the zip file
#
# Returns:
#   0: The checksum matches the zip file
#   1: The checksum is invalid
verify_sha1_checksum() {
    local checksum="$1"
    local file="$2"

    if ! echo "${checksum} ${file}" | sha1sum --check --strict --quiet; then
        error_return "SHA1 checksum verification failed for ${file}"
        return 1
    fi

    return 0
}

# Returns the HTTP status code for the specified url. All other output from
# curl is discarded. This can be used to check the validity of urls, for
# example the WildFly download url.
#
# Params:
#   $1:  url  the url for which to get the status code
#
# Returns:
#   stdout: the HTTP status code
_get_url_status() {
    local url="$1"
    curl --retry 3 --silent --head --write-out "%{http_code}" --output /dev/null --location "${url}"
}

# Copies all WAR files in the target/ directory to the WildFly directory for
# deployment. The function fails if the target/ directory does not exist or
# there are no WAR files in that directory.
#
# Params:
#   $1:  buildDir   The Heroku build directory
#   $2:  jbossHome  The WildFly root directory
#
# Returns:
#   0: The WAR files were deployed successfully
#   1: The deployment failed due to an error
_deploy_war_files() {
    local buildDir="$1"
    local jbossHome="$2"

    if [ ! -d "${buildDir}/target" ]; then
        error_return "Could not deploy WAR files: Target directory does not exist"
        return 1
    fi

    local war_glob=("${buildDir}"/target/*.war)
    if [ "${war_glob[*]}" == "${buildDir}/target/*.war" ]; then
        error_return "No WAR files found in target/ directory.
        
Please ensure your Maven build configuration in the pom.xml is creating
the necessary WAR file(s) for your application under the target/ directory.

For help on the usage of the maven-war-plugin visit
https://maven.apache.org/plugins/maven-war-plugin/usage.html."
        return 1
    fi

    status "Deploying WAR file(s):"
    local war
    for war in "${buildDir}"/target/*.war; do
        echo "  - ${war#*target/}" | indent
        cp "${war}" "${JBOSS_HOME}/standalone/deployments"
    done
    echo "done" | indent
}

# Checks if a web process configuration in the Procfile exists and creates a
# web process type if necessary.
#
# Params:
#   $1:  buildDir  The Heroku build directory
#
# Returns:
#   exit code 0 and a process configuration in the Procfile
_create_process_configuration() {
    local buildDir="$1"
    local procFile="${buildDir}/Procfile"

    status_pending "Creating process configuration"
    if [ -f "${procFile}" ] && grep -q "^web:" "${procFile}"; then
        echo " Using existing process type 'web' in Procfile"
    else
        echo "web: \${JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0 -Djboss.http.port=\$PORT" >> "${procFile}"
        echo " done"
    fi
}

# Creates a .profile.d script to load the environment variables for the
# WildFly server when the dyno starts up. The values for the environment
# variables are passed as arguments.
#
# Params:
#   $1:  buildDir        The Heroku build directory
#   $2:  jbossHome       The WildFly root directory
#   $3:  jbossCli        The path to the jboss-cli.sh script
#   $4:  wildflyVersion  The WildFly version
#
# Returns:
#   exit status 0 and the .profile.d script
_create_profile_script() {
    local buildDir="$1"
    local profileScript="${buildDir}/.profile.d/wildfly.sh"
    local jbossHome="$2"
    local jbossCli="$3"
    local wildflyVersion="$4"

    if [ -d "${buildDir}/.profile.d" ]; then
        status_pending "Creating .profile.d script for environment variables"
        cat > "${profileScript}" <<SCRIPT
export JBOSS_HOME="${jbossHome}"
export JBOSS_CLI="${jbossCli}"
export WILDFLY_VERSION="${wildflyVersion}"
SCRIPT
        status_done
    fi
}

# Downloads the JVM Common Buildpack if not already existing and sources the
# utility functions used throughout this script such as 'indent', 'error_return'
# and 'status'.
#
# Returns:
#   always 0
_load_jvm_common_buildpack() {
    local JVM_COMMON_BUILDPACK_URL="${JVM_COMMON_BUILDPACK_URL:-"https://buildpack-registry.s3.amazonaws.com/buildpacks/heroku/jvm.tgz"}"

    local jvmCommonDir="/tmp/jvm-common"
    if [ ! -d "${jvmCommonDir}" ]; then
        mkdir -p "${jvmCommonDir}"
        curl --retry 3 --silent --location "${JVM_COMMON_BUILDPACK_URL}" | tar xzm -C "${jvmCommonDir}" --strip-components=1
    fi

    source "${jvmCommonDir}/bin/util"
}

# Load the JVM Common buildpack
_load_jvm_common_buildpack
