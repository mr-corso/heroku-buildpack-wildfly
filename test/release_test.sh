#!/bin/sh
#
# shellcheck disable=SC1090

. "${BUILDPACK_HOME}/test/test_helper.sh"

testReleaseOutput() {
    release

    assertCaptured "default_process_types:"
    assertCaptured "  web: \${JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0 -Djboss.http.port=\${PORT}"
    assertCapturedSuccess
}
