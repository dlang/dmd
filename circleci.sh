#!/bin/bash

set -uexo pipefail

HOST_DMD_VER=2.068.2 # same as in dmd/src/posix.mak
CURL_USER_AGENT="CirleCI $(curl --version | head -n 1)"
N=2

case $CIRCLE_NODE_INDEX in
    0) MODEL=64 ;;
    1) MODEL=32 ;;
esac

install_deps() {
    if [ $MODEL -eq 32 ]; then
        sudo apt-get update
        sudo apt-get install g++-multilib
    fi

    for i in {0..4}; do
        if curl -fsS -A "$CURL_USER_AGENT" --max-time 5 https://dlang.org/install.sh -O; then
            break
        elif [ $i -ge 4 ]; then
            sleep $((1 << $i))
        else
            echo 'Failed to download install script' 1>&2
            exit 1
        fi
    done

    source "$(CURL_USER_AGENT=\"$CURL_USER_AGENT\" bash install.sh dmd-$HOST_DMD_VER --activate)"
    $DC --version
    env
}

# clone dmd
clone() {
    local url="$1"
    local path="$2"
    local branch="$3"
    for i in {0..4}; do
        if git clone --depth=1 --branch "$branch" "$url" "$path"; then
            break
        elif [ $i -lt 4 ]; then
            sleep $((1 << $i))
        else
            echo "Failed to clone: ${url}"
            exit 1
        fi
    done
}

coverage() {
    if [ -n "${CIRCLE_PR_NUMBER:-}" ]; then
        local base_branch=$(curl -fsSL https://api.github.com/repos/dlang/$CIRCLE_PROJECT_REPONAME/pulls/$CIRCLE_PR_NUMBER | jq -r '.base.ref')
    else
        local base_branch=$CIRCLE_BRANCH
    fi

    clone https://github.com/dlang/dmd.git ../dmd $base_branch

    # load environment for bootstrap compiler
    source "$(CURL_USER_AGENT=\"$CURL_USER_AGENT\" bash ~/dlang/install.sh dmd-$HOST_DMD_VER --activate)"

    # build dmd and druntime
    make -j$N -C ../dmd/src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD all
    make -j$N -C ../dmd/src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD dmd.conf
    TEST_COVERAGE="1" make -j$N -C . -f posix.mak MODEL=$MODEL unittest-debug
}

case $1 in
    install-deps) install_deps ;;
    coverage) coverage ;;
esac
