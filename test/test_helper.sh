#!/bin/sh
#
# shellcheck disable=SC1090

. "${BUILDPACK_TEST_RUNNER_HOME}/lib/test_utils.sh"

import() {
    module="$1"

    if [ -f "${BUILDPACK_HOME}/lib/${module}.sh" ]; then
        . "${BUILDPACK_HOME}/lib/${module}.sh"
    elif [ -f "${BUILDPACK_HOME}/test/${module}.sh" ]; then
        . "${BUILDPACK_HOME}/test/${module}.sh"
    else
        fail "ERROR: Module not found: ${module}"
        exit 1
    fi

    unset module
}
