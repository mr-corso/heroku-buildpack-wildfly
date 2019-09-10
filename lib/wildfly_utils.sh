#!/usr/bin/env bash

function use_wildfly_version() {
    local properties_file="$1"
    local backreference_var="$2"

    if [ -f "${properties_file}" ] &&
        grep -E "^[[:blank:]]*[^#]" "${properties_file}" | grep -Eq "wildfly\.version[[:blank:]]*="; then
        local wildfly_version="$(grep -E "^[[:blank:]]*[^#]" "${properties_file}" | \
            grep -E "wildfly\.version[[:blank:]]*=[[:blank:]]*[A-Za-z0-9\.]+$" | \
            sed "s/^[^=]*=//")"
        printf -v "${backreference_var}" "%s" "${wildfly_version}"
    fi
}
