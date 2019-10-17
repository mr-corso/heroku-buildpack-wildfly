#!/usr/bin/env bash

[ "${CI}" != "true" ] && echo "Not running on CI!" && exit 1

if [ -n "${HEROKU_API_KEY}" ]; then
    heroku keys:remove "${USER}@$(hostname)"
fi
