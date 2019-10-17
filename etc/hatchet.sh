#!/usr/bin/env bash

# Exit the script on error
set -e

BUILDPACK="mortenterhart/heroku-buildpack-wildfly"

# Skip integration tests in forked pull request
# on Circle CI
if [ "${CIRCLECI}" == "true" ] && [ -n "${CIRCLE_PULL_REQUEST}" ]; then
    if [ "${CIRCLE_PR_USERNAME}" != "${CIRCLE_PROJECT_USERNAME}" ]; then
        echo "Skipping integration tests on forked PR."
        exit 0
    fi
fi

# Skip integration tests in forked pull request
# on Travis CI
if [ "${TRAVIS}" == "true" ] && [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
    if [ "${TRAVIS_PULL_REQUEST_SLUG}" != "${BUILDPACK}" ]; then
        echo "Skipping integration tests on forked PR."
        exit 0
    fi
fi

# Fail if $HEROKU_API_KEY is missing
if [ -z "${HEROKU_API_KEY}" ]; then
    echo
    echo "ERROR: Missing \$HEROKU_API_KEY"
    echo
    echo "NOTE: You can create this token by running"
    echo "  $ heroku authorizations:create --description \"For Travis\""
    echo
    echo "Then you need to add it to your .travis.yml by running"
    echo "  $ travis encrypt HEROKU_API_KEY=<token> --add"
    echo
    echo "See https://github.com/heroku/hatchet for more information."
    echo
    exit 1
fi

# Determine the branch to test with Hatchet
if [ -n "${CIRCLE_BRANCH}" ]; then
    export HATCHET_BUILDPACK_BRANCH="${CIRCLE_BRANCH}"
elif [ -n "${TRAVIS_PULL_REQUEST_BRANCH}" ]; then
    export HATCHET_BUILDPACK_BRANCH="${TRAVIS_PULL_REQUEST_BRANCH}"
else
    # shellcheck disable=SC2155
    export HATCHET_BUILDPACK_BRANCH="$(git name-rev HEAD 2>/dev/null | sed 's#HEAD\ \(.*\)#\1#' | sed 's#tags\/##')"
fi

# Print the following commands
set -x

gem update --system
gem install bundler --version=2.0.2

bundle install
bundle exec hatchet ci:setup

# Disable printing and exiting on error
set +ex

export HATCHET_RETRIES="3"
export HATCHET_APP_LIMIT="5"
export HATCHET_APP_PREFIX="htcht-${TRAVIS_JOB_ID}-"
export HATCHET_DEPLOY_STRATEGY="git"
export HATCHET_BUILDPACK_BASE="https://github.com/${BUILDPACK}.git"

# Execute the specs in parallel
bundle exec parallel_rspec -n "${MAX_CONCURRENT_BUILDS:-1}" "$@"
RETURN=$?

# Destroy any remaining apps
bundle exec hatchet destroy --all

exit "${RETURN}"
