#!/usr/bin/env bash

assertEnvContains() {
    local variable="$1"

    env | grep -q -- "^${variable}"
    assertTrue "Environment doesn't contain '${variable}'" $?
}

assertEnvNotContains() {
    local variable="$1"

    env | grep -q -- "^${variable}"
    assertFalse "Environment contains '${variable}'" $?
}

assertEnvDiffContains() {
    local variable="$1"
    local envBefore="$2"
    local envAfter="$3"

    diff <(echo "${envBefore}" | sort) <(echo "${envAfter}" | sort) | \
        grep -q -- "${variable}"
    assertTrue "Environment doesn't differ in '${variable}'" $?
}
