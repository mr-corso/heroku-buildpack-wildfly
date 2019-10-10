#!/usr/bin/env bash
#
# shellcheck disable=SC1090

source "${BUILDPACK_TEST_RUNNER_HOME}/lib/test_utils.sh"

import() {
    local module="$1"

    if [ -f "${BUILDPACK_HOME}/lib/${module}.sh" ]; then
        source "${BUILDPACK_HOME}/lib/${module}.sh"
    elif [ -f "${BUILDPACK_HOME}/test/${module}.sh" ]; then
        source "${BUILDPACK_HOME}/test/${module}.sh"
    else
        fail "ERROR: Module not found: ${module}"
        exit 1
    fi
}
