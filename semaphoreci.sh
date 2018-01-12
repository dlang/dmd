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
export BRANCH=$BRANCH_NAME
export FULL_BUILD="${PULL_REQUEST_NUMBER+false}"

source ci.sh

################################################################################
# Cache the compiler installation on Semaphore
# See also: https://semaphoreci.com/docs/caching-between-builds.html#additional-dir-caching
################################################################################

mkdir -p "$SEMAPHORE_CACHE_DIR/dlang"
ln -s "$SEMAPHORE_CACHE_DIR/dlang" "$HOME/dlang"

################################################################################
# Always source a DMD instance
################################################################################

source "$(activate_d "$DMD")"

################################################################################
# Define commands
################################################################################

case $1 in
    setup) setup_repos ;;
    testsuite) testsuite ;;
esac
