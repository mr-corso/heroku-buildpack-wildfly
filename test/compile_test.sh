#!/usr/bin/env bash
#
# shellcheck disable=SC1090

source "${BUILDPACK_HOME}/test/module_loader.sh"

import "wildfly"

import "lib/deployment_helper"

### --- SETUP HOOKS ---

setUpOnce() {
    echo "### setUpOnce ###"

    TEST_CACHE="/tmp/test-cache"
    mkdir -p "${TEST_CACHE}"

    WILDFLY_ZIP="${TEST_CACHE}/wildfly-${DEFAULT_WILDFLY_VERSION}.zip"
    if [ ! -f "${WILDFLY_ZIP}" ]; then
        download_wildfly "${DEFAULT_WILDFLY_VERSION}" "${WILDFLY_ZIP}"
    else
        status "Using WildFly ${DEFAULT_WILDFLY_VERSION} from cache"
    fi

    echo "## END setUpOnce ###"
}

### --- HELPER FUNCTIONS ---

useCachedWildfly() {
    cp "${WILDFLY_ZIP}" "${CACHE_DIR}"
}

createJavaMock() {
    JDK_DIR="${BUILD_DIR}/.jdk"

    mkdir -p "${JDK_DIR}/bin"
    cat <<'EOF' > "${JDK_DIR}/bin/java"
#!/usr/bin/env bash
# This is a Java mocking script to prevent
# the compile script from downloading and
# installing a complete JDK

exec /usr/bin/env java "$@"
EOF
}

### --- TESTS ---

testCompile() {
    useCachedWildfly
    createDeployment
    createJavaMock

    compile

    assertCapturedSuccess
}
