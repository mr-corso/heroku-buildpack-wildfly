#!/usr/bin/env bash

assertFileExists() {
    local message
    if [ $# -eq 2 ]; then
        message="$1"
        shift
    fi

    local file="$1"
    message="${message:-"File does not exist: ${file}"}"

    assertTrue "${message}" "[ -f '${file}' ]"
}

assertFileNotExists() {
    local message
    if [ $# -eq 2 ]; then
        message="$1"
        shift
    fi

    local file="$1"
    message="${message:-"File exists: ${file}"}"

    assertFalse "${message}" "[ -f '${file}' ]"
}

assertDirExists() {
    local message
    if [ $# -eq 2 ]; then
        message="$1"
        shift
    fi

    local dir="$1"
    message="${message:-"Directory does not exist: ${dir}"}"

    assertTrue "${message}" "[ -d '${dir}' ]"
}

assertDirNotExists() {
    local message
    if [ $# -eq 2 ]; then
        message="$1"
        shift
    fi

    local dir="$1"
    message="${message:-"Directory exists: ${dir}"}"

    assertFalse "${message}" "[ -d '${dir}' ]"
}

assertGlobExpands() {
    local pattern="$1"

    # Glob expansion is desired here
    # shellcheck disable=SC2116,SC2086
    assertNotEquals "Glob did not expand: ${pattern}" "${pattern}" "$(echo ${pattern})"
}

assertGlobNotExpands() {
    local pattern="$1"

    # Glob expansion is desired here
    # shellcheck disable=SC2116,SC2086
    assertEquals "Glob did expand: ${pattern}" "${pattern}" "$(echo ${pattern})"
}

assertDirEmpty() {
    local message
    if [ $# -eq 2 ]; then
        message="$1"
        shift
    fi

    local dir="$1"
    message="${message:-"Directory is not empty: ${dir}"}"

    if assertDirExists "${dir}"; then
        assertNull "${message}" "$(ls -- "${dir}")"
    fi
}

assertDirNotEmpty() {
    local message

    if [ $# -eq 2 ]; then
        message="$1"
        shift
    fi

    local dir="$1"
    message="${message:-"Directory is empty: ${dir}"}"

    if assertDirExists "${dir}"; then
        assertNotNull "${message}" "$(ls -- "${dir}")"
    fi
}
