#!/usr/bin/env bash

[ "${CI}" != "true" ] && echo "Not running on CI!" && exit 1

# Retry a specific setup step if it failed. Use the
# --times <int> option to specify the number of retry
# attempts. The default is to retry 3 times.
#
# Usage:
#   $ retry git clone <git-url>
#   $ retry --times 5 git clone <git-url>
retry() {
    local times=3
    if [ "$1" == "--times" ]; then
        times="$2"
        shift 2
    fi

    local count=1
    while [ "${count}" -le "${times}" ]; do
        if "$@"; then
            return
        fi

        local exitCode=$?
        (( count++ ))
        echo "Command failed with exit code ${exitCode}. Retrying ${count} of ${times} times..."
    done
}

# Download Shunit 2.1.7 from GitHub
curl --retry 3 --location --silent "https://github.com/kward/shunit2/archive/v2.1.7.tar.gz" | tar xz -C /tmp/
export SHUNIT_HOME="/tmp/shunit2-2.1.7"

# Copy the Shunit2 script to where the Heroku Buildpack
# Testrunner expects it to be
mkdir -p "${SHUNIT_HOME}/src"
cp "${SHUNIT_HOME}/shunit2" "${SHUNIT_HOME}/src"

retry git clone "https://github.com/heroku/heroku-buildpack-testrunner.git" /tmp/testrunner

git config --global user.email "${HEROKU_API_USER:-"buildpack@example.com"}"
git config --global user.name 'BuildpackTester'

cat <<EOF >> ~/.ssh/config
Host heroku.com
    StrictHostKeyChecking no
    CheckHostIP no
    UserKnownHostsFile=/dev/null
Host github.com
    StrictHostKeyChecking no
EOF

cat <<EOF >> ~/.netrc
machine git.heroku.com
  login ${HEROKU_API_USER:-"buildpack@example.com"}
  password ${HEROKU_API_KEY:-"password"}
EOF

sudo apt-get -qq update
sudo apt-get install software-properties-common -y
curl --fail --retry 3 --retry-delay 1 --connect-timeout 3 --max-time 30 "https://cli-assets.heroku.com/install-ubuntu.sh" | sh

if [ -n "${HEROKU_API_KEY}" ]; then
    yes | heroku keys:add
fi
