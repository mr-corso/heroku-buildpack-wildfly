#!/usr/bin/env bash
#
# shellcheck disable=SC1090

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

# Always import lib/test_utils for rudimentary capturing
# and assert functions
import "lib/test_utils"
