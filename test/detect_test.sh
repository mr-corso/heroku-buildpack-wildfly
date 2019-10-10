#!/usr/bin/env bash
#
# shellcheck disable=SC1090

source "${BUILDPACK_HOME}/test/test_helper.sh"

import "capture_assertions"

createDeployment() {
    local target="${BUILD_DIR}/target"
    mkdir -p "${target}"
    echo "This is a WAR file" > "${target}/deployment.war"
}

testDetectSuccess() {
    createDeployment

    detect

    assertCapturedSuccess
    assertAppDetected "WildFly"
}

testDetectFailure() {
    # Don't create deployment WAR file

    detect

    assertCapturedExitCode 1
    assertCapturedStderrContains "No WAR files found in 'target' directory for deployment"
}
