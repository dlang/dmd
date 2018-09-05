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

# FIXME: v2.082.0 has a broken DUB which fails the CI
# Remove this when a fixed v2.082.1 is released
# See https://github.com/dlang/dub/issues/1551
if [ "$DMD" == "dmd" ]; then
    install_d "dmd-2.081.2"
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
