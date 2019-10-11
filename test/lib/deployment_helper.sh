#!/usr/bin/env bash
#
# shellcheck disable=SC1090

createTargetDirectory() {
    TARGET_DIR="${BUILD_DIR}/target"
    mkdir -p "${TARGET_DIR}"
}

createDeployment() {
    createTargetDirectory
    echo "This is a WAR file" > "${TARGET_DIR}/deployment.war"
}
