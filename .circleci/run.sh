#!/bin/bash

set -uexo pipefail

HOST_DMD_VER=2.079.1
CURL_USER_AGENT="CirleCI $(curl --version | head -n 1)"
N=4
CIRCLE_NODE_INDEX=${CIRCLE_NODE_INDEX:-0}
CIRCLE_PROJECT_REPONAME=${CIRCLE_PROJECT_REPONAME:-druntime}

case $CIRCLE_NODE_INDEX in
    0) MODEL=64 ;;
    1) MODEL=32 ;; # broken - https://issues.dlang.org/show_bug.cgi?id=19116
esac

download() {
    local url="$1"
    local fallbackurl="$2"
    local outputfile="$3"
    for i in {0..4}; do
        if curl -fsS -A "$CURL_USER_AGENT" --max-time 5 "$url" -o "$outputfile" ||
           curl -fsS -A "$CURL_USER_AGENT" --max-time 5 "$fallbackurl" -o "$outputfile" ; then
            break
        elif [ $i -ge 4 ]; then
            sleep $((1 << $i))
        else
            echo "Failed to download script ${outputfile}" 1>&2
            exit 1
        fi
    done
}

install_deps() {
    sudo apt-get update
    if [ $MODEL -eq 32 ]; then
        sudo apt-get install -y g++-multilib
    fi
    sudo apt-get install -y gdb

    download "https://dlang.org/install.sh" "https://nightlies.dlang.org/install.sh" "install.sh"

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
        if git clone --branch "$branch" "$url" "$path" "${@:4}"; then
            break
        elif [ $i -lt 4 ]; then
            sleep $((1 << $i))
        else
            echo "Failed to clone: ${url}"
            exit 1
        fi
    done
}

setup_repos() {
    # set a default in case we run into rate limit restrictions
    local base_branch=""
    if [ -n "${CIRCLE_PR_NUMBER:-}" ]; then
        base_branch=$((curl -fsSL https://api.github.com/repos/dlang/$CIRCLE_PROJECT_REPONAME/pulls/$CIRCLE_PR_NUMBER || echo) | jq -r '.base.ref')
    else
        base_branch=$CIRCLE_BRANCH
    fi
    base_branch=${base_branch:-"master"}

   # merge upstream branch with changes, s.t. we check with the latest changes
    if [ -n "${CIRCLE_PR_NUMBER:-}" ]; then
        local head=$(git rev-parse HEAD)
        git remote add upstream "https://github.com/dlang/$CIRCLE_PROJECT_REPONAME.git"
        git fetch -q upstream "+refs/pull/${CIRCLE_PR_NUMBER}/merge:"
        git checkout -f FETCH_HEAD
    fi

    for proj in dmd ; do
        if [ $base_branch != master ] && [ $base_branch != stable ] &&
            ! git ls-remote --exit-code --heads https://github.com/dlang/$proj.git $base_branch > /dev/null; then
            # use master as fallback for other repos to test feature branches
            clone https://github.com/dlang/$proj.git ../$proj master --depth 1
        else
            clone https://github.com/dlang/$proj.git ../$proj $base_branch --depth 1
        fi
    done
}

style() {
    make -f posix.mak style
}

coverage() {
    # load environment for bootstrap compiler
    source "$(CURL_USER_AGENT=\"$CURL_USER_AGENT\" bash ~/dlang/install.sh dmd-$HOST_DMD_VER --activate)"

    # build dmd (release) and druntime (debug)
    make -j$N -C ../dmd/src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD BUILD="release" all
    TEST_COVERAGE="1" make -j$N -C . -f posix.mak MODEL=$MODEL unittest-debug
}

betterc()
{
    clone https://github.com/dlang/tools.git ../tools master --depth 1
    make -f posix.mak betterc -j$N DUB="$HOME/dlang/dmd-${HOST_DMD_VER}/linux/bin64/dub"
}

publictests()
{
    # checkout a specific version of https://github.com/dlang/tools
    if [ ! -d ../tools ] ; then
        clone https://github.com/dlang/tools.git ../tools master --depth 1
    fi

    make -f posix.mak  publictests -j$N DUB="$HOME/dlang/dmd-${HOST_DMD_VER}/linux/bin64/dub"
}

codecov()
{
    OS_NAME=linux source ../dmd/ci/codecov.sh
}

case $1 in
    install-deps) install_deps ;;
    setup-repos) setup_repos ;;
    style) style ;;
    betterc) betterc ;;
    publictests) publictests ;;
    coverage) coverage ;;
    codecov) codecov ;;
esac
