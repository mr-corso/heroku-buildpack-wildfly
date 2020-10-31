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

# We need the buildpack directory here to create the export script for the
# WildFly environment variables. For this, resolve the buildpack root
# directory as an absolute path.
BUILDPACK_DIR="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"

# Loads script files from the lib/ directory and other buildpacks that this
# script file depends on. This script uses functions coming from other script
# files or buildpacks which are loaded before to prevent overriding functions
# from this script.
#
# Returns:
#   always 0
_load_dependent_scripts() {
    local scriptDir="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"

    # Load dependent buildpacks
    source "${scriptDir}/load_buildpacks.sh"

    # Load scripts
    source "${scriptDir}/environment.sh"   # Override JVM common functions
    source "${scriptDir}/errors.sh"
    source "${scriptDir}/warnings.sh"
    source "${scriptDir}/debug.sh"
}

# Load other script files and unset the function
_load_dependent_scripts
unset -f _load_dependent_scripts

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
    local buildDir="$1" && debug_var "buildDir"
    local cacheDir="$2" && debug_var "cacheDir"
    if [ ! -d "${buildDir}" ]; then
        error_return "Failed to install WildFly: Build directory does not exist: ${buildDir}"
        return 1
    fi
    if [ ! -d "${cacheDir}" ]; then
        error_return "Failed to install WildFly: Cache directory does not exist: ${cacheDir}"
        return 1
    fi

    # Identify WildFly versions
    local wildflyVersion="${3:-$(detect_wildfly_version "${buildDir}")}"
    debug_mmeasure "version" "${wildflyVersion}"

    # Specify zip filename to download to
    local wildflyZip="wildfly-${wildflyVersion}.zip"

    # Download WildFly to cache if not already existing
    if [ ! -f "${cacheDir}/${wildflyZip}" ]; then
        download_wildfly "${wildflyVersion}" "${cacheDir}/${wildflyZip}"
    else
        status "Using WildFly ${wildflyVersion} from cache"
    fi

    local installStart="$(nowms)"

    status_pending "Installing WildFly ${wildflyVersion}"

    # Remove the .jboss directory if it exists
    local jbossDir="${buildDir}/.jboss"
    if [ -d "${jbossDir}" ]; then
        debug "Removing existing .jboss directory: ${jbossDir}"
        rm -rf "${jbossDir}"
    fi

    # Create the .jboss directory
    mkdir -p "${jbossDir}"

    # Unzip the contents
    debug_command "unzip -d \"${jbossDir}\" -q \"${cacheDir}/${wildflyZip}\""
    unzip -d "${jbossDir}" -q "${cacheDir}/${wildflyZip}"

    status_done
    debug_mtime "installation.time" "${installStart}"

    # Export environment variables
    export JBOSS_HOME="${jbossDir}/wildfly-${wildflyVersion}"
    export JBOSS_CLI="${JBOSS_HOME}/bin/jboss-cli.sh"
    export WILDFLY_VERSION="${WILDFLY_VERSION:-${wildflyVersion}}"

    _deploy_war_files "${buildDir}"
    _create_process_configuration "${buildDir}"
    _create_wildfly_profile_script "${buildDir}"
    _create_wildfly_export_script "${BUILDPACK_DIR}"
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
    debug_mmeasure "download.url" "${wildflyUrl}"

    # Validate the url for the specific version
    if ! validate_wildfly_url "${wildflyUrl}" "${wildflyVersion}"; then
        mcount "download.url.invalid"
        return 1
    fi

    local -i downloadStart="$(nowms)"
    status_pending "Downloading WildFly ${wildflyVersion} to cache"
    curl --retry 3 --silent --location --output "${targetFilename}" "${wildflyUrl}"
    status_done
    debug_mtime "download.time" "${downloadStart}"

    # Verify the checksum
    status "Verifying SHA1 checksum"
    local wildflySHA1="$(curl --retry 3 --silent --location "${wildflyUrl}.sha1")"
    if ! verify_sha1_checksum "${wildflySHA1}" "${targetFilename}"; then
        mcount "sha1.verification.fail"
        return 1
    fi
    mcount "sha1.verification.success"
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
        # Redirect error message to stderr to prevent
        # being captured by command substitutions
        error_return "Failed to detect WildFly version: Build directory does not exist: ${buildDir}" >&2
        return 1
    fi

    local systemProperties="${buildDir}/system.properties"
    if [ -f "${systemProperties}" ]; then
        local detectedVersion="$(get_app_system_property "${systemProperties}" "wildfly.version")"
        if [ -n "${detectedVersion}" ]; then
            echo "${detectedVersion}"
        else
            echo "${DEFAULT_WILDFLY_VERSION}"
        fi
    else
        echo "${DEFAULT_WILDFLY_VERSION}"
    fi
}

# Reads a system property from a properties file and outputs its value.
# Outputs nothing if the given property name is not defined or the file
# does not exist. The file and property arguments are required. They cause
# an error if they were not defined.
#
# Params:
#   $1:  file      the properties file
#   $2:  property  the name of the property
#
# Returns:
#   stdout: the value of the property if existing or nothing
get_app_system_property() {
    local file="${1?"No file specified"}"
    local property="${2?"No property specified"}"

    # Escape property for regex
    local escapedProperty="${property//./\\.}"

    if [ -f "${file}" ]; then
        # Remove comments and print property value
        sed -E '/^[[:blank:]]*\#/d' "${file}" | \
        grep -E "^[[:blank:]]*${escapedProperty}[[:blank:]]*=" | \
        sed -E "s/[[:blank:]]*${escapedProperty}[[:blank:]]*=[[:blank:]]*//"
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
        error_unsupported_wildfly_version "${wildflyVersion}" "${DEFAULT_WILDFLY_VERSION}"
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
#   $1:  buildDir  The Heroku build directory
#
# Returns:
#   0: The WAR files were deployed successfully
#   1: The deployment failed due to an error
_deploy_war_files() {
    local buildDir="$1"
    
    # customize app build dir
    local appBuildDir = "${buildDir}/server/zanata-war"

    if [ ! -d "${appBuildDir}/target" ]; then
        error_return "Could not deploy WAR files: Target directory does not exist"
        return 1
    fi

    local warFiles=("${appBuildDir}"/target/*.war)
    if [ "${warFiles[*]}" == "${appBuildDir}/target/*.war" ]; then
        error_no_war_files_found
        return 1
    fi

    debug "Found following WAR file(s): ${warFiles[*]}"

    status "Deploying WAR file(s):"
    local war
    for war in "${warFiles[@]}"; do
        local warBasename="${war#*target/}"
        echo "  - ${warBasename}" | indent
        cp "${war}" "${JBOSS_HOME}/standalone/deployments"

        mcount "deploy.${warBasename%.war}.success"
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
        mcount "existing.process.type.web"
    else
        echo "web: \${JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0 -Djboss.http.port=\$PORT" >> "${procFile}"
        echo " done"
        mcount "creating.process.type.web"
    fi

    debug_file "${procFile}"
}

# Creates a .profile.d script to load the environment variables for the
# WildFly server when the dyno starts up. These variables are provided
# for the deployment.
#
# Params:
#   $1:  buildDir  The Heroku build directory
#
# Returns:
#   exit status 0 and the .profile.d script
_create_wildfly_profile_script() {
    local buildDir="$1"
    local profileScript="${buildDir}/.profile.d/wildfly.sh"

    status_pending "Creating .profile.d script for WildFly environment variables"
    mkdir -p "${buildDir}/.profile.d"
    cat > "${profileScript}" <<SCRIPT
# Environment variables for the WildFly installation
export JBOSS_HOME="\${HOME}/.jboss/wildfly-${WILDFLY_VERSION}"
export JBOSS_CLI="\${JBOSS_HOME}/bin/jboss-cli.sh"
export WILDFLY_VERSION="${WILDFLY_VERSION}"

# Set the log manager to prevent WFLYCTL0013 error
export JAVA_TOOL_OPTIONS="\${JAVA_TOOL_OPTIONS} -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
SCRIPT
    status_done
    mcount "profile.script"
    debug_file "${profileScript}"
}

# Creates an export script for subsequent buildpacks to load the
# WildFly environment that is setup through this buildpack. This
# is important because the paths used in the build differ from
# those that are used after deployment. The build paths use the
# build directory as prefix whereas the productive variables
# start with '$HOME' which is '/app'.
#
# Params:
#   $1:  buildpackDir  The root directory of this buildpack
#
# Returns:
#   exit status 0 and the export script
_create_wildfly_export_script() {
    local buildpackDir="$1"

    cat > "${buildpackDir}/export" <<SCRIPT
# Environment variables for subsequent buildpacks
export JBOSS_HOME="${buildDir}/.jboss/wildfly-${WILDFLY_VERSION}"
export JBOSS_CLI="\${JBOSS_HOME}/bin/jboss-cli.sh"
export WILDFLY_VERSION="${WILDFLY_VERSION}"
SCRIPT
    mcount "export.script"
    debug_file "${buildpackDir}/export"
}
