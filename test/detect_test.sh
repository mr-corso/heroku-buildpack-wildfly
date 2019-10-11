#!/usr/bin/env bash
#
# shellcheck disable=SC1090

source "${BUILDPACK_HOME}/test/module_loader.sh"

import "assertions/capture_assertions"
import "lib/deployment_helper"

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
