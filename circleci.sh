#!/bin/bash

set -uexo pipefail

HOST_DMD_VER=2.068.2 # same as in dmd/src/posix.mak
CURL_USER_AGENT="CirleCI $(curl --version | head -n 1)"
N=2

case $CIRCLE_NODE_INDEX in
    0) MODEL=64 ;;
    1) MODEL=32 ;;
esac

# clone druntime and phobos
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

install_deps() {
    if [ $MODEL -eq 32 ]; then
        sudo aptitude install g++-multilib --assume-yes --quiet=2
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

coverage() {
    if [ -n "${CIRCLE_PR_NUMBER:-}" ]; then
        local base_branch=$(curl -fsSL https://api.github.com/repos/dlang/dmd/pulls/$CIRCLE_PR_NUMBER | jq -r '.base.ref')
    else
        local base_branch=$CIRCLE_BRANCH
    fi

    for proj in druntime phobos; do
        if [ $base_branch != master ] && [ $base_branch != stable ] &&
               ! curl -fsSLI https://api.github.com/repos/dlang/$proj/branches/$base_branch; then
            # use master as fallback for other repos to test feature branches
            clone https://github.com/dlang/$proj.git ../$proj master
        else
            clone https://github.com/dlang/$proj.git ../$proj $base_branch
        fi
    done

    # load environment for bootstrap compiler
    source "$(CURL_USER_AGENT=\"$CURL_USER_AGENT\" bash ~/dlang/install.sh dmd-$HOST_DMD_VER --activate)"

    # build dmd, druntime, and phobos
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD all
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD dmd.conf
    make -j$N -C ../druntime -f posix.mak MODEL=$MODEL
    make -j$N -C ../phobos -f posix.mak MODEL=$MODEL

    # rebuild dmd with coverage enabled
    # use the just build dmd as host compiler this time
    mv src/dmd src/host_dmd
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=./host_dmd clean
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=./host_dmd dmd.conf
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=./host_dmd ENABLE_COVERAGE=1

    make -j$N -C test MODEL=$MODEL ARGS="-O -inline -release" DMD_TEST_COVERAGE=1
}

case $1 in
    install-deps) install_deps ;;
    coverage) coverage ;;
esac
