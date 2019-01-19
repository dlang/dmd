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
export BRANCH

source ci.sh

################################################################################
# Always source a DMD instance
################################################################################

# Later versions of LDC causes a linker error.
if  [ "$DMD" == "ldc" ]; then
    LDC_VERSION=1.11.0
    DUB_VERSION=1.13.0

    install_d "ldc-$LDC_VERSION"
    source ~/dlang/ldc-$LDC_VERSION/activate

    # Older versions of LDC are shipped with a version of Dub that doesn't
    # support the `DUB_EXE` environment variable
    curl -o dub.tar.gz -L https://github.com/dlang/dub/releases/download/v$DUB_VERSION/dub-v$DUB_VERSION-linux-x86_64.tar.gz
    tar xf dub.tar.gz
    # Replace default dub with newer version
    mv dub $(which dub)
    deactivate
else
    install_d "$DMD"
fi

################################################################################
# Define commands
################################################################################

case $1 in
    setup) setup_repos ;;
    testsuite) testsuite ;;
esac
