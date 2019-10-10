#!/usr/bin/env bash
#
# shellcheck disable=SC1090,SC2155

source "${BUILDPACK_HOME}/test/test_helper.sh"

import "environment"

addEnvVar() {
    local varname="$1"
    local value="$2"

    echo "${value}" > "${ENV_DIR}/${varname}"
}

assertEnvContains() {
    local variable="$1"

    env | grep -q -- "^${variable}"
    assertTrue "Environment doesn't contain '${variable}'" $?
}

assertEnvDiffContains() {
    local variable="$1"
    local envBefore="$2"
    local envAfter="$3"

    diff <(echo "${envBefore}" | sort) <(echo "${envAfter}" | sort) | \
        grep -q -- "${variable}"
    assertTrue "Environment doesn't differ in '${variable}'" $?
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
