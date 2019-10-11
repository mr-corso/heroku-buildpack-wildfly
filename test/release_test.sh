#!/usr/bin/env bash
#
# shellcheck disable=SC1090

source "${BUILDPACK_HOME}/test/module_loader.sh"

testReleaseOutput() {
    release

    assertCaptured "default_process_types:"
    assertCaptured "  web: \${JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0 -Djboss.http.port=\${PORT}"
    assertCapturedSuccess
}
