#!/usr/bin/env bash

assertCapturedExitCode() {
    local message=""

    if [ $# -eq 2 ]; then
        message="$1"
        shift
    fi

    local actualExitCode="$1"

    if [ -z "${RETURN}" ]; then
        fail "No command was captured before, \$RETURN is null"
        return 1
    fi

    # $RETURN is the exit status of the last captured command
    assertEquals "${message}" "${RETURN}" "${actualExitCode}"
}

assertCapturedStderrContains() {
    local message=""

    if [ $# -eq 2 ]; then
        message="$1"
        shift
    fi

    local content="$1"

    if [ ! -f "${STD_ERR}" ]; then
        fail "ERROR: \$STD_ERR file does not exist"
        return 1
    fi

    # Don't confuse this call with the 'assertContains' function provided
    # by shUnit2. Version 2.1.7 of shUnit2 does not provide the function
    # yet, but it is provided by the test_utils.sh of the Heroku buildpack
    # testrunner. This function expects the content to be the first and the
    # container to be the second argument:
    #
    #   assertContains [message] content container
    #
    # See https://github.com/heroku/heroku-buildpack-testrunner/blob/master/lib/test_utils.sh
    # for more information.
    assertContains "${content}" "$(cat "${STD_ERR}")"
}
