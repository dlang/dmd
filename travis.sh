#!/bin/bash

set -uexo pipefail

################################################################################
# Static variables or inferred from Travis
# https://docs.travis-ci.com/user/environment-variables/
################################################################################

export N=2
export OS_NAME="${TRAVIS_OS_NAME}"
export MODEL="${MODEL}"
export BRANCH="${TRAVIS_BRANCH}"
export FULL_BUILD=false

source ci.sh

################################################################################
# Commands
################################################################################

setup_repos
testsuite
