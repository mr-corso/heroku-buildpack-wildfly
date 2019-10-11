#!/usr/bin/env bash
#
# shellcheck disable=SC1090,SC2155

source "${BUILDPACK_HOME}/test/test_helper.sh"

import "wildfly"

import "assertions/capture_assertions"
import "assertions/env_assertions"

### --- Setup Hooks ---

setUpOnce() {
    echo "### setUpOnce ###"

    TEST_CACHE="/tmp/test-cache"
    mkdir -p "${TEST_CACHE}"

    WILDFLY_ZIP="${TEST_CACHE}/wildfly-${DEFAULT_WILDFLY_VERSION}.zip"
    if [ ! -f "${WILDFLY_ZIP}" ]; then
        download_wildfly "${DEFAULT_WILDFLY_VERSION}" "${WILDFLY_ZIP}"
    else
        status "Using WildFly ${DEFAULT_WILDFLY_VERSION} from cache"
    fi

    echo "## END setUpOnce ###"
}

### --- Helper functions ---

createTargetDirectory() {
    TARGET_DIR="${BUILD_DIR}/target"
    mkdir -p "${TARGET_DIR}"
}

createDeployment() {
    createTargetDirectory
    echo "This is a WAR file" > "${TARGET_DIR}/deployment.war"
}

createSystemProperty() {
    local property="$1"
    local value="$2"

    echo "${property}=${value}" >> "${BUILD_DIR}/system.properties"
}

resetSystemProperties() {
    rm "${BUILD_DIR}/system.properties"
}

getDefaultWildflyUrl() {
    _get_wildfly_download_url "${DEFAULT_WILDFLY_VERSION}"
}

getInvalidWildflyUrl() {
    _get_wildfly_download_url "undefined-version"
}

setupJbossHome() {
    export JBOSS_HOME="${BUILD_DIR}/.jboss/wildfly-${DEFAULT_WILDFLY_VERSION}"
    mkdir -p "${JBOSS_HOME}"
    mkdir -p "${JBOSS_HOME}/standalone/deployments"
}

### --- TESTS ---

testInstallWildfly() {
    local wildflyVersion="${DEFAULT_WILDFLY_VERSION}"

    createSystemProperty "wildfly.version" "${wildflyVersion}"

    # Prevent the function from downloading the WildFly server again
    cp "${WILDFLY_ZIP}" "${CACHE_DIR}"

    createDeployment

    capture install_wildfly "${BUILD_DIR}" "${CACHE_DIR}"

    assertCapturedSuccess
    assertCaptured "Using WildFly ${wildflyVersion} from cache"
    assertCaptured "Installing WildFly ${wildflyVersion}"
    assertCaptured "Deploying WAR file(s)"
    assertCaptured "Creating process configuration"
    assertCaptured "Creating .profile.d script for WildFly environment variables"

    assertEnvContains "JBOSS_HOME"
    assertEnvContains "JBOSS_CLI"
    assertEnvContains "WILDFLY_VERSION"
}

testDownloadWildfly() {
    local wildflyVersion="17.0.0.Final"
    local wildflyZip="${CACHE_DIR}/wildfly-${wildflyVersion}.zip"

    capture download_wildfly "${wildflyVersion}" "${wildflyZip}"

    assertCapturedSuccess
    assertCaptured "Downloading WildFly ${wildflyVersion} to cache"
    assertCaptured "Verifying SHA1 checksum"
    assertTrue "Downloaded .zip file does not exist" "[ -f '${wildflyZip}' ]"
}

testDetectWildflyVersion() {
    # Use a non-existing build directory
    capture detect_wildfly_version "${OUTPUT_DIR}/other-build"

    assertCapturedExitCode 1
    assertCapturedStderrContains "Build directory exists" "Build directory does not exist: ${OUTPUT_DIR}/other-build"

    # Execute without system.properties file
    capture detect_wildfly_version "${BUILD_DIR}"

    assertCapturedSuccess
    assertCapturedEquals "Default version was not chosen" "${DEFAULT_WILDFLY_VERSION}"

    # Create the Java version property not detected
    # by this function
    createSystemProperty "java.runtime.version" "11"

    # The wildfly.version property is not defined
    # and thus expect to choose the default version
    capture detect_wildfly_version "${BUILD_DIR}"

    assertCapturedSuccess
    assertCapturedEquals "Default version was not chosen" "${DEFAULT_WILDFLY_VERSION}"

    # Define the wildfly.version property finally
    # and detect this version
    createSystemProperty "wildfly.version" "17.0.0.Final"

    capture detect_wildfly_version "${BUILD_DIR}"

    assertCapturedSuccess
    assertCapturedEquals "Custom version was not chosen" "17.0.0.Final"
}

testGetAppSystemProperty() {
    createSystemProperty "wildfly.version" "17.0.0.Final"

    local propertiesFile="${BUILD_DIR}/system.properties"

    # Test an existing property
    capture get_app_system_property "${propertiesFile}" "wildfly.version"

    assertCapturedSuccess
    assertCapturedEquals "17.0.0.Final"

    # Test a non-existing property
    capture get_app_system_property "${propertiesFile}" "java.runtime.version"

    assertCapturedSuccess
    assertCapturedEquals "Property was defined unexpectedly" ""

    # Test a non-existing file
    capture get_app_system_property "${BUILD_DIR}/other.properties" "wildfly.version"

    assertCapturedSuccess
    assertCapturedEquals "Unexpected output" ""

    resetSystemProperties
}

testValidateWildflyUrl() {
    local wildflyUrl="$(getDefaultWildflyUrl)"

    capture validate_wildfly_url "${wildflyUrl}" "${DEFAULT_WILDFLY_VERSION}"

    assertCapturedSuccess
    assertCapturedEquals "stdout is not empty" ""

    local invalidUrl="$(getInvalidWildflyUrl)"

    capture validate_wildfly_url "${invalidUrl}" "undefined-version"

    assertCapturedError 1 "Unsupported WildFly version: undefined-version"
}

testVerifySha1Checksum() {
    local wildflyUrl="$(getDefaultWildflyUrl)"
    local checksum="$(curl --retry 3 --silent --location "${wildflyUrl}.sha1")"

    capture verify_sha1_checksum "${checksum}" "${WILDFLY_ZIP}"

    assertCapturedSuccess

    # Take an invalid SHA-1 checksum to test a failed
    # checksum verification
    checksum="caa52e60808b8fff674d4c61a421d0c78dea80df"

    capture verify_sha1_checksum "${checksum}" "${WILDFLY_ZIP}"

    assertCapturedExitCode 1
    assertCaptured "SHA1 checksum verification failed for ${WILDFLY_ZIP}"
    assertCapturedStderrContains "sha1sum: WARNING: 1 computed checksum did NOT match"
}

testGetUrlStatus() {
    local wildflyUrl="$(getDefaultWildflyUrl)"

    capture _get_url_status "${wildflyUrl}"

    assertCapturedSuccess
    assertCapturedEquals "WildFly download url is invalid" "200"

    local invalidUrl="$(getInvalidWildflyUrl)"

    capture _get_url_status "${invalidUrl}"

    assertCapturedSuccess
    assertCapturedEquals "WildFly url is valid" "404"
}

testDeployWarFiles() {
    # Don't create target directory

    capture _deploy_war_files "${BUILD_DIR}"

    assertCapturedError 1 "Target directory does not exist"

    createTargetDirectory

    # Don't create WAR files to be deployed

    capture _deploy_war_files "${BUILD_DIR}"

    assertCapturedError 1 "No WAR files found in 'target' directory"

    setupJbossHome
    createDeployment

    capture _deploy_war_files "${BUILD_DIR}"

    assertCapturedSuccess
    assertTrue "WAR file was not deployed" "[ -f '${JBOSS_HOME}/standalone/deployments/deployment.war' ]"
}

testCreateProcessConfiguration() {
    local procFile="${BUILD_DIR}/Procfile"

    capture _create_process_configuration "${BUILD_DIR}"

    assertCapturedSuccess
    assertCaptured "done"
    assertTrue "Procfile does not exist" "[ -f '${procFile}' ]"
    assertFileContains "web: \${JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0 -Djboss.http.port=\$PORT" "${procFile}"

    capture _create_process_configuration "${BUILD_DIR}"

    assertCapturedSuccess
    assertCaptured "Using existing process type 'web' in Procfile"
    assertTrue "Didn't use existing process type 'web'" "[ '$(wc -l "${procFile}" | awk '{ print $1; }')' -eq 1 ]"
}

testCreateWildflyProfileScript() {
    local profileScript="${BUILD_DIR}/.profile.d/wildfly.sh"

    capture _create_wildfly_profile_script "${BUILD_DIR}"

    assertCapturedSuccess
    assertCaptured "Creating .profile.d script for WildFly environment variables"
    assertTrue "WildFly .profile.d script does not exist" "[ -f '${profileScript}' ]"
    assertFileContains "export JBOSS_HOME=" "${profileScript}"
    assertFileContains "export JBOSS_CLI=" "${profileScript}"
    assertFileContains "export WILDFLY_VERSION=" "${profileScript}"
    assertFileContains "export JAVA_TOOL_OPTIONS=" "${profileScript}"
}

testCreateWildflyExportScript() {
    local exportScript="${BUILDPACK_HOME}/export"

    capture _create_wildfly_export_script "${BUILDPACK_HOME}"

    assertCapturedSuccess
    assertTrue "WildFly export script does not exist" "[ -f '${exportScript}' ]"
    assertFileContains "export JBOSS_HOME=" "${exportScript}"
    assertFileContains "export JBOSS_CLI=" "${exportScript}"
    assertFileContains "export WILDFLY_VERSION=" "${exportScript}"
}
