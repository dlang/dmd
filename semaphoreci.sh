#!/bin/bash

set -uexo pipefail

################################################################################
# Set by the Semaphore job runner
################################################################################

export MODEL=${MODEL:-64}      # can be {32,64}
export DMD=${DMD:-dmd}         # can be {dmd,ldc,gdc}

################################################################################
# Static variables or inferred from Semaphore
# See also: https://semaphoreci.com/docs/available-environment-variables.html
################################################################################

export N=4
export OS_NAME=linux
export FULL_BUILD="${PULL_REQUEST_NUMBER+false}"
export DUB_EXE="${DUB_EXE:-dub}"

export HOST_DC=$DMD
if [ "$HOST_DC" == "gdc" ]; then export HOST_DC=gdmd-$GDC_VERSION; fi

# SemaphoreCI doesn't provide a convenient way to the base branch (e.g. master or stable)
if [ -n "${PULL_REQUEST_NUMBER:-}" ]; then
    BRANCH=$((curl -fsSL https://api.github.com/repos/dlang/dmd/pulls/$PULL_REQUEST_NUMBER || echo) | jq -r '.base.ref')
    # check if the detected branch actually exists and fallback to master
    if ! git ls-remote --exit-code --heads https://github.com/dlang/dmd.git "$BRANCH" > /dev/null ; then
        echo "Invalid branch detected: ${BRANCH} - falling back to master"
        BRANCH="master"
    fi
else
    BRANCH="${BRANCH_NAME}"
fi

################################################################################
# Define commands
################################################################################

case $1 in
    setup) ./ci.sh install_host_compiler && ./ci.sh setup_repos "$BRANCH" ;;
    testsuite) ./ci.sh testsuite ;;
esac
