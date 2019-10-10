#!/bin/sh
#
# shellcheck disable=SC1090

. "${BUILDPACK_HOME}/test/test_helper.sh"

import "capture_assertions"

createDeployment() {
    TARGET="${BUILD_DIR}/target"
    mkdir -p "${TARGET}"
    echo "This is a WAR file" > "${TARGET}/deployment.war"
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
