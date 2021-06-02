#!/bin/bash
# This script allows auto-bootstrapping by downloading a suitable D compiler.
# Usage: ./bootstrap.sh <build-args>
# It is a wrapper around src/build.d and all arguments will be passed to build.d
# For more information, please see the documentation of build.d.
#
# We recommend installing a D compiler globally and using src/build.d directly.
# Visit https://dlang.org/download.html for more information

set -euo pipefail

HOST_DMD_VER="${HOST_DMD_VER:-2.095.0}"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
GENERATED="$( cd "$DIR/.." >/dev/null 2>&1 && pwd )/generated"
CURL_FLAGS=(-fsSL --retry 5 --retry-max-time 120 --connect-timeout 5 --speed-time 30 --speed-limit 1024)

# detect model
uname_m="$(uname -m)"
if [[ "$uname_m" =~ "x86_64" ]] || [[ "$uname_m" =~ "amd64" ]] ; then
    MODEL=64
elif [[ "$uname_m" =~ "i386" ]] || [[ "$uname_m" =~ "i586" ]] || [[ "$uname_m" =~ "i686" ]] ; then
    MODEL=32
else
    echo "Unrecognized or unsupported model for uname: $uname_m"
    exit 1
fi

# detect OS
uname_s="$(uname -s)"
if [ "$uname_s" == "Darwin" ] ; then
    OS=osx
    MODEL_PATH=bin
elif [ "$uname_s" == "Linux" ] ; then
    OS=linux
    MODEL_PATH="bin${MODEL}"
elif [ "$uname_s" == "FreeBSD" ] ; then
    OS=freebsd
    MODEL_PATH="bin${MODEL}"
else
    echo "Unrecognized or unsupported OS for uname: $uname_s"
    exit 1
fi

HOST_DMD_ROOT="${GENERATED}/host_dmd-${HOST_DMD_VER}"
if [ "$OS" == "freebsd" ] ; then
    # dmd.2.095.0.freebsd-64.tar.xz
    HOST_DMD_BASENAME=dmd.${HOST_DMD_VER}.${OS}-${MODEL}
else
    # dmd.2.095.0.osx.zip or dmd.2.095.0.linux.tar.xz
    HOST_DMD_BASENAME=dmd.${HOST_DMD_VER}.${OS}
fi
# http://downloads.dlang.org/releases/2.x/2.095.0/dmd.2.095.0.linux.tar.xz
HOST_DMD_URL=http://downloads.dlang.org/releases/2.x/${HOST_DMD_VER}/${HOST_DMD_BASENAME}
HOST_RDMD="${HOST_DMD_ROOT}/dmd2/${OS}/${MODEL_PATH}/rdmd"
HOST_DMD="${HOST_DMD_ROOT}/dmd2/${OS}/${MODEL_PATH}/dmd" # required by build.d

# Download bootstrap compiler if it does not exist yet
if [ ! -e "${HOST_RDMD}" ] ; then
    mkdir -p "${HOST_DMD_ROOT}"

    # prefer xz if available
    if command -v xz &> /dev/null ; then
        echo "[boostrap] Downloading compiler ${HOST_DMD_URL}.tar.xz"
        curl "${CURL_FLAGS[@]}" "${HOST_DMD_URL}.tar.xz" | tar -C "${HOST_DMD_ROOT}" -Jxf - || rm -rf "${HOST_DMD_ROOT}"
    else
        echo "[bootstrap] Downloading compiler ${HOST_DMD_URL}.zip"
        TMPFILE="$(mktemp deleteme.XXXXXXXX.zip)"
        ( curl "${CURL_FLAGS[@]}" "${HOST_DMD_URL}.zip" -o "${TMPFILE}"
          unzip -qd "${HOST_DMD_ROOT}" "${TMPFILE}"
          ) ||  rm -rf "${HOST_DMD_ROOT}"
        rm -f "${TMPFILE}"
    fi

    # check for bootstrapping success
    if [ -e "${HOST_RDMD}" ] ; then
        echo "[bootstrap] Compiler download successful."
    else
        echo "ERROR: bootstrapping failed."
        exit 1
    fi
fi

# Call build.d with all arguments forwarded
"$HOST_RDMD" "$DIR/build.d" "$@" HOST_DMD="$HOST_DMD"
