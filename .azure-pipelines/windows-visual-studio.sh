#!/usr/bin/env bash

set -euxo pipefail

CURL_USER_AGENT="DMD-CI $(curl --version | head -n 1)"
DMD_DIR="$PWD"

download() {
    local url="$1"
    local path="$2"
    curl -fsSL -A "$CURL_USER_AGENT" --connect-timeout 5 --speed-time 30 --speed-limit 1024 --retry 5 --retry-delay 5 "$url" -o "$path"
}

clone() {
    local url="$1"
    local path="$2"
    local branch="$3"
    for i in {0..4}; do
        if git clone --depth 1 --branch "$branch" "$url" "$path" "${@:4}" --quiet; then
            break
        elif [ $i -lt 4 ]; then
            sleep $((1 << $i))
        else
            echo "Failed to clone: ${url}"
            exit 1
        fi
    done
}

################################################################################
# Download LDC
################################################################################

ldc() {
    LDC_DIR="ldc2-${LDC_VERSION}-windows-multilib"
    LDC_INSTALLER="${LDC_DIR}.7z"
    LDC_URL="https://github.com/ldc-developers/ldc/releases/download/v${LDC_VERSION}/${LDC_INSTALLER}"

    if [ ! -e "$LDC_INSTALLER" ] ; then
        download "$LDC_URL" "$LDC_INSTALLER"
    fi

    7z x "$LDC_INSTALLER" > /dev/null
    if [ ! -e "$LDC_DIR/bin/ldmd2.exe" ] ; then
      echo "Unexpected LDC installation, $LDC_INSTALLER/bin/ldmd2.exe missing"
      exit 1
    fi
}

################################################################################
# Download VisualD
################################################################################

visuald() {
    local VISUALD_INSTALLER="VisualD-${VISUALD_VER}.exe"
    local VISUALD_URL="https://github.com/dlang/visuald/releases/download/${VISUALD_VER}/${VISUALD_INSTALLER}"
    if [ ! -e "$VISUALD_INSTALLER" ] ; then
        download "$VISUALD_URL" "$VISUALD_INSTALLER"
    fi
}

################################################################################
# Download DigitalMars Make
################################################################################

dm_make() {
    download "http://downloads.dlang.org/other/dm857c.zip" dmc.zip
    unzip dmc.zip > /dev/null
    export DMC="$PWD/dm/bin/dmc.exe"
    export DM_MAKE="$PWD/dm/bin/make.exe"
    mkdir -p dm/path
    cp "$DMC" "$DM_MAKE" "dm/path"
}

################################################################################
# Download DigitalMars Make
################################################################################

install_grep() {
    local tools_dir="${DMD_DIR}/tools"
    mkdir -p "$tools_dir"
    cd "$tools_dir"
    download "http://downloads.dlang.org/other/grep-3.1.zip" "grep-3.1.zip"
    unzip "grep-3.1.zip" # contains grep.exe
    #export PATH="${tools_dir}:$PATH"
}

################################################################################
# Checkout other repositories
################################################################################

clone_repos() {
    local REPO_BRANCH="$SYSTEM_PULLREQUEST_TARGETBRANCH"

    for proj in druntime phobos; do
        if [ "$REPO_BRANCH" != master ] && [ "$REPO_BRANCH" != stable ] &&
                ! git ls-remote --exit-code --heads "https://github.com/dlang/$proj.git" "$REPO_BRANCH" > /dev/null; then
            # use master as fallback for other repos to test feature branches
            clone "https://github.com/dlang/$proj.git" "${DMD_DIR}/../$proj" master
            echo "[GIT_CLONE] Switched $proj to branch master \$(REPO_BRANCH=$REPO_BRANCH)"
        else
            clone "https://github.com/dlang/$proj.git" "${DMD_DIR}/../$proj" "$REPO_BRANCH"
            echo "[GIT_CLONE] Switched $proj to branch $REPO_BRANCH"
        fi
    done
}

echo "[STEP]: Downloading LDC"
ldc

echo "[STEP]: Downloading VisualD"
visuald

echo "[STEP]: Downloading DigitalMars make"
dm_make

echo "[STEP]: Downloading grep"
install_grep

echo "[STEP]: Cloning repositories"
clone_repos
