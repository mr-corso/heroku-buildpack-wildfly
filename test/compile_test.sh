#!/usr/bin/env bash
#
# shellcheck disable=SC1090

source "${BUILDPACK_HOME}/test/module_loader.sh"

import "wildfly"

import "assertions/capture_assertions"
import "assertions/file_assertions"
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
    JBOSS_HOME="${BUILD_DIR}/.jboss/wildfly-${DEFAULT_WILDFLY_VERSION}"
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

addConfigVar() {
    local variable="$1"
    local value="$2"

    echo "${value}" > "${ENV_DIR}/${variable}"
}

configureWildflyVersion() {
    local version="$1"

    echo "wildfly.version=${version}" > "${BUILD_DIR}/system.properties"
}

### --- TESTS ---

testCompileSuccess() {
    useCachedWildfly
    createDeployment
    createJavaMock

    compile

    assertCapturedSuccess

    # Check that a log was created
    assertDirExists "${CACHE_DIR}/logs"
    assertDirNotEmpty "${CACHE_DIR}/logs"

    # Check that JVM common was installed
    assertDirExists "/tmp/jvm-common"

    # Check that a JDK was installed
    assertDirExists "${BUILD_DIR}/.jdk"
    assertFileExists "${BUILD_DIR}/.jdk/bin/java"

    # Check that WildFly 16 was installed and deployed
    assertDirExists "${JBOSS_HOME}"
    assertGlobExpands "${JBOSS_HOME}/standalone/deployments/*.war"
}

testCompileDebug() {
    useCachedWildfly
    createDeployment
    createJavaMock

    addConfigVar "BUILDPACK_DEBUG" "true"

    compile

    assertCapturedSuccess
    assertCaptured "DEBUG: buildDir=${BUILD_DIR}"
    assertCaptured "DEBUG: cacheDir=${CACHE_DIR}"
}

testCompileWithoutTargetDir() {
    useCachedWildfly
    createJavaMock

    # Don't create target/ directory

    compile

    assertCapturedError 1 "Could not deploy WAR files: Target directory does not exist"
}

testCompileWithoutDeployment() {
    useCachedWildfly
    createJavaMock

    # Create target/ directory, but no WAR files
    # for deployment
    createTargetDirectory

    compile

    assertCapturedError 1 "No WAR files found in 'target' directory"
}

testCompileInvalidWildflyVersion() {
    useCachedWildfly
    createDeployment
    createJavaMock

    configureWildflyVersion "undefined"

    compile

    assertCapturedError 1 "Unsupported WildFly version: undefined"
}
