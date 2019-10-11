#!/usr/bin/env bash
#
# shellcheck disable=SC1090,SC2155

source "${BUILDPACK_HOME}/test/test_helper.sh"

import "wildfly"
import "capture_assertions"

oneTimeSetUp() {
    echo "### oneTimeSetUp ###"
    WILDFLY_ZIP="${SHUNIT_TMPDIR}/wildfly-${DEFAULT_WILDFLY_VERSION}.zip"
    download_wildfly "${DEFAULT_WILDFLY_VERSION}" "${WILDFLY_ZIP}"
}

createTargetDirectory() {
    TARGET_DIR="${BUILD_DIR}/target"
    mkdir -p "${TARGET_DIR}"
}

createDeployment() {
    createTargetDirectory
    echo "This is a WAR file" > "${TARGET_DIR}/deployment.war"
}

setupJbossHome() {
    export JBOSS_HOME="${BUILD_DIR}/.jboss/wildfly-${DEFAULT_WILDFLY_VERSION}"
    mkdir -p "${JBOSS_HOME}"
    mkdir -p "${JBOSS_HOME}/standalone/deployments"
}

testVerifySha1Checksum() {
    local wildflyUrl="$(_get_wildfly_download_url "${DEFAULT_WILDFLY_VERSION}")"
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
    local wildflyUrl="$(_get_wildfly_download_url "${DEFAULT_WILDFLY_VERSION}")"

    capture _get_url_status "${wildflyUrl}"

    assertCapturedSuccess
    assertCapturedEquals "WildFly download url is invalid" "200"

    local invalidUrl="$(_get_wildfly_download_url "invalid-version")"

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
}

testCreateProcessConfiguration() {
    _create_process_configuration "${BUILD_DIR}"

    local procFile="${BUILD_DIR}/Procfile"

    assertTrue "Procfile does not exist" "[ -f '${procFile}' ]"
    assertFileContains "web: \${JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0 -Djboss.http.port=\$PORT" "${procFile}"

    _create_process_configuration "${BUILD_DIR}"

    assertTrue "Didn't use existing process type 'web'" "[ '$(wc -l "${procFile}" | awk '{ print $1; }')' -eq 1 ]"
}

testCreateWildflyProfileScript() {
    _create_wildfly_profile_script "${BUILD_DIR}"

    local profileScript="${BUILD_DIR}/.profile.d/wildfly.sh"

    assertTrue "WildFly .profile.d script does not exist" "[ -f '${profileScript}' ]"
    assertFileContains "export JBOSS_HOME=" "${profileScript}"
    assertFileContains "export JBOSS_CLI=" "${profileScript}"
    assertFileContains "export WILDFLY_VERSION=" "${profileScript}"
    assertFileContains "export JAVA_TOOL_OPTIONS=" "${profileScript}"
}

testCreateWildflyExportScript() {
    _create_wildfly_export_script "${BUILDPACK_HOME}"

    local exportScript="${BUILDPACK_HOME}/export"

    assertTrue "WildFly export script does not exist" "[ -f '${exportScript}' ]"
    assertFileContains "export JBOSS_HOME=" "${exportScript}"
    assertFileContains "export JBOSS_CLI=" "${exportScript}"
    assertFileContains "export WILDFLY_VERSION=" "${exportScript}"
}
