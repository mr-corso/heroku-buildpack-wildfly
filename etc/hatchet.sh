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

# Suppresses the extensive changelog that is output when
# updating RubyGems. The process output may be piped to
# this function.
suppress_changelog() {
    if [ -t 0 ]; then
        echo "ERROR: Input on stdin expected"
        return 1
    fi

    awk 'BEGIN {
        blank_line = 0
    }
    {
        # Stop printing input when the first
        # blank line is found
        if ($0 ~ /^ *$/) {
            blank_line = 1
        }
        if (!blank_line) {
            print $0
        }
    }'
}

# Print the following commands
set -x

gem update --system | suppress_changelog
gem install bundler --version=2.0.2

bundle install
bundle exec hatchet install

heroku update

# Disable printing and exiting on error
set +ex

# Determines whether the account associated with the
# $HEROKU_API_KEY is verified or not. This is important
# for compliance with the app and build limits. Unverified
# accounts can only hold 5 apps in total and can only run
# one build at a time.
is_heroku_account_verified() {
    curl --retry 3 --location --netrc --silent "https://api.heroku.com/account" \
        -H "Accept: application/vnd.heroku+json; version=3" | \
        ruby -e '
require "json"

account = JSON.parse(STDIN.read)
puts account["verified"]' | grep -q "true"
}

# Use concurrent builds with Hatchet only if the
# associated Heroku account is verified
if is_heroku_account_verified; then
    export HATCHET_APP_LIMIT="100"
    export HEROKU_MAX_CONCURRENT_BUILDS="5"
else
    export HATCHET_APP_LIMIT="5"
    export HEROKU_MAX_CONCURRENT_BUILDS="1"
fi

export HATCHET_RETRIES="3"
export HATCHET_APP_PREFIX="htcht-${TRAVIS_JOB_ID}-"
export HATCHET_DEPLOY_STRATEGY="git"
export HATCHET_BUILDPACK_BASE="https://github.com/${BUILDPACK}.git"

echo "---"
echo "Executing INTEGRATION TESTS"
echo "  Using app limit ${HATCHET_APP_LIMIT} with ${HEROKU_MAX_CONCURRENT_BUILDS} concurrent process(es)"
echo "  Hatchet App Prefix: ${HATCHET_APP_PREFIX}"
echo "---"

# Execute the specs in parallel
bundle exec parallel_rspec -n "${HEROKU_MAX_CONCURRENT_BUILDS}" "$@"
RETURN=$?

# Destroy any remaining apps
bundle exec hatchet destroy --all

exit "${RETURN}"
