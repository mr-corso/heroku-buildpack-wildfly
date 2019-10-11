#!/usr/bin/env bash
#
# shellcheck disable=SC1090,SC2155

source "${BUILDPACK_HOME}/test/module_loader.sh"

import "environment"
import "assertions/env_assertions"

addEnvVar() {
    local varname="$1"
    local value="$2"

    echo "${value}" > "${ENV_DIR}/${varname}"
}

testExportEmptyEnvDir() {
    # Keep ENV_DIR empty

    local envBefore="$(env)"

    capture export_env_dir "${ENV_DIR}"

    local envAfter="$(env)"

    assertCapturedSuccess
    assertEquals "${envBefore}" "${envAfter}"
}

testExportEnvDirWithConfigVar() {
    addEnvVar "BUILDPACK_DEBUG" "true"

    local envBefore="$(env)"

    capture export_env_dir "${ENV_DIR}"

    local envAfter="$(env)"

    assertCapturedSuccess
    assertEnvContains "BUILDPACK_DEBUG"
    assertNotEquals "${envBefore}" "${envAfter}"

    # Check that $envBefore and $envAfter differ
    # in the BUILDPACK_DEBUG variable
    assertEnvDiffContains "BUILDPACK_DEBUG" "${envBefore}" "${envAfter}"
}

testExportEnvDirWhitelist() {
    addEnvVar "BUILDPACK_DEBUG" "true"

    # Use explicit whitelist to export BUILDPACK_DEBUG
    capture export_env_dir "${ENV_DIR}" "BUILDPACK_DEBUG"

    assertCapturedSuccess
    assertEnvContains "BUILDPACK_DEBUG"

    unset BUILDPACK_DEBUG

    # Use other whitelist so that BUILDPACK_DEBUG
    # is not exported
    capture export_env_dir "${ENV_DIR}" "OTHER_WHITELIST"

    assertCapturedSuccess
    assertEnvNotContains "BUILDPACK_DEBUG"
}

testExportEnvDirBlacklist() {
    addEnvVar "BUILDPACK_DEBUG" "true"

    capture export_env_dir "${ENV_DIR}" "." "BUILDPACK_DEBUG"

    assertCapturedSuccess
    assertEnvNotContains "BUILDPACK_DEBUG"

    capture export_env_dir "${ENV_DIR}" "" "OTHER_BLACKLIST"

    assertCapturedSuccess
    assertEnvContains "BUILDPACK_DEBUG"

    unset BUILDPACK_DEBUG
}
