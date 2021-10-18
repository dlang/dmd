#!/usr/bin/env bash

set -euxo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. "$DIR"/lib.sh

CURL_USER_AGENT="DMD-CI $(curl --version | head -n 1)"
DMD_DIR="$PWD"

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

if [ "$D_COMPILER" == "ldc" ]; then
    echo "[STEP]: Downloading LDC"
    ldc
else
    echo "[STEP]: Downloading DMD"
    install_host_dmd
fi

echo "[STEP]: Downloading VisualD"
visuald

echo "[STEP]: Downloading DigitalMars make"
dm_make

echo "[STEP]: Downloading grep"
install_grep
