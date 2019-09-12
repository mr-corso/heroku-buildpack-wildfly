#!/usr/bin/env bash
#
# It is recommended to use 'set -e' to abort execution on any command exiting
# with a non-zero exit status so that execution will not continue on an error.
#
# shellcheck disable=SC1090,SC2155

DEFAULT_WILDFLY_VERSION="16.0.0.Final"

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

    # Identify WildFly version
    local wildflyVersion="${3:-$(detect_wildfly_version "${buildDir}")}"

    # Get WildFly url for the specific version
    local wildflyUrl="$(_get_wildfly_download_url "${wildflyVersion}")"
    local wildflyZip="wildfly-${wildflyVersion}.zip"

    # Download WildFly to cache if not already existing
    if [ ! -f "${cacheDir}/${wildflyZip}" ]; then
        # Validate the url for the specific version
        if ! validate_wildfly_url "${wildflyUrl}" "${wildflyVersion}"; then
            return 1
        fi

        status_pending "Downloading WildFly ${wildflyVersion} to cache"
        curl --retry 3 --silent --location -o "${cacheDir}/${wildflyZip}" "${wildflyUrl}"
        status_done

        # Verify the checksum
        status "Verifying SHA1 checksum"
        local wildflySHA1="$(curl --retry 3 --silent --location "${wildflyUrl}.sha1")"
        if ! verify_sha1_checksum "${wildflySHA1}" "${cacheDir}/${wildflyZip}"; then
            return 1
        fi
    else
        status "Using WildFly ${wildflyVersion} from cache"
    fi

    status "Installing WildFly ${wildflyVersion} ..."

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

    status "Installation of WildFly ${wildflyVersion} finished successfully"

    # Export environment variables
    export JBOSS_HOME="${jbossDir}/wildfly-${wildflyVersion}"
    export JBOSS_CLI="${JBOSS_HOME}/bin/jboss-cli.sh"
    export WILDFLY_VERSION="${WILDFLY_VERSION:-${wildflyVersion}}"

    _deploy_war_files "${buildDir}" "${JBOSS_HOME}"
    _create_process_configuration "${buildDir}" "${JBOSS_HOME}" "${WILDFLY_VERSION}"
    _create_profile_script "${buildDir}" "${JBOSS_HOME}" "${JBOSS_CLI}" "${WILDFLY_VERSION}"
}

detect_wildfly_version() {
    local buildDir="$1"

    if [ ! -d "${buildDir}" ]; then
        error_return "Could not detect WildFly version: Build directory does not exist"
        return 1
    fi

    local systemProperties="${buildDir}/system.properties"
    if [ -f "${systemProperties}" ]; then
        if grep -E "^[[:blank:]]*[^#]" "${systemProperties}" | grep -Eq "wildfly\.version[[:blank:]]*="; then
            local detectedVersion="$(grep -E "^[[:blank:]]*[^#]" "${systemProperties}" | \
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

_get_wildfly_download_url() {
    local wildflyVersion="$1"

    local wildflyBaseUrl="https://download.jboss.org/wildfly"
    local wildflyDownloadUrl="${wildflyBaseUrl}/${wildflyVersion}/wildfly-${wildflyVersion}.zip"

    echo "${wildflyDownloadUrl}"
}

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

verify_sha1_checksum() {
    local checksum="$1"
    local file="$2"

    if ! echo "${checksum} ${file}" | sha1sum --check --strict --quiet; then
        error_return "SHA1 checksum verification failed for ${file}"
        return 1
    fi

    return 0
}

_get_url_status() {
    local url="$1"
    curl --retry 3 --silent --head --write-out "%{http_code}" --output /dev/null --location "${url}"
}

_deploy_war_files() {
    local buildDir="$1"
    local jbossHome="$2"

    status "Deploying WAR file(s):"
    local war
    for war in target/*.war; do
        echo "  - ${war#target/}" | indent
        cp "${war}" "${JBOSS_HOME}/standalone/deployments"
    done
    echo "done" | indent
}

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

_create_profile_script() {
    local buildDir="$1"
    local profileScript="${buildDir}/.profile.d/wildfly.sh"
    local jbossHome="$2"
    local jbossCli="$3"
    local wildflyVersion="$4"

    status_pending "Create .profile.d script for environment variables"
    cat > "${profileScript}" <<SCRIPT
export JBOSS_HOME="${jbossHome}"
export JBOSS_CLI="${jbossCli}"
export WILDFLY_VERSION="${wildflyVersion}"
SCRIPT
    status_done
}

_load_jvm_common_buildpack() {
    local JVM_COMMON_BUILDPACK_URL="${JVM_COMMON_BUILDPACK_URL:-"https://codon-buildpacks.s3.amazonaws.com/buildpacks/heroku/jvm-common.tgz"}"

    local jvmCommonDir="/tmp/jvm-common"
    if [ ! -d "${jvmCommonDir}" ]; then
        mkdir -p "${jvmCommonDir}"
        curl --retry 3 --silent --location "${JVM_COMMON_BUILDPACK_URL}" | tar xzm -C "${jvmCommonDir}" --strip-components=1
    fi

    source "${jvmCommonDir}/bin/util"
}

_load_jvm_common_buildpack
