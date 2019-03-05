#!/bin/sh

set -eux -o pipefail

CURL_USER_AGENT="DMD-CI $(curl --version | head -n 1)"
DMD_DIR="$PWD"
GNU_MAKE="$(which make)"
N=$(($(nproc)+1))

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

download() {
    local url="$1"
    local path="$2"
    curl -fsSL -A "$CURL_USER_AGENT" --connect-timeout 5 --speed-time 30 --speed-limit 1024 --retry 5 --retry-delay 5 "$url" -o "$path"
}

install_host_dmd() {
    download "http://downloads.dlang.org/releases/2.x/${HOST_DMD_VERSION}/dmd.${HOST_DMD_VERSION}.windows.7z" dmd.7z
    7z x dmd.7z > /dev/null
    export PATH="$PWD/dmd2/windows/bin/:$PATH"
    export HOST_DC="$PWD/dmd2/windows/bin/dmd.exe"
    export DM_MAKE="$PWD/dmd2/windows/bin/make.exe"
}

install_host_ldc() {
    local LDC_INSTALLER="ldc2-${HOST_LDC_VERSION}-windows-${ARCH}"
    download "https://github.com/ldc-developers/ldc/releases/download/v${HOST_LDC_VERSION}/${LDC_INSTALLER}.7z" ldc.7z
    7z x ldc.7z > /dev/null
    export PATH="$PWD/${LDC_INSTALLER}/bin/:$PATH"
    export HOST_DC="$PWD/${LDC_INSTALLER}/bin/ldmd2.exe"
}

install_dm_make() {
    download "http://downloads.dlang.org/other/dm857c.zip" dmc.zip
    unzip dmc.zip > /dev/null
    export DMC="$PWD/dm/bin/dmc.exe"
    export DM_MAKE="$PWD/dm/bin/make.exe"
}

install_grep() {
    local tools_dir="${DMD_DIR}/tools"
    mkdir -p "$tools_dir"
    cd "$tools_dir"
    download "http://downloads.dlang.org/other/grep-3.1.zip" "grep-3.1.zip"
    unzip "grep-3.1.zip" # contains grep.exe
    export PATH="${tools_dir}:$PATH"
}

################################################################################
# Setup required tools
################################################################################

# WORKAROUND: install a newer grep version
# REASON: the preinstalled version is buggy (see also: https://github.com/dlang/dmd/pull/9398#issuecomment-468773638)
install_grep

echo "D_VERSION: $HOST_DMD_VERSION"
echo "VSINSTALLDIR: $VSINSTALLDIR"
echo "GNU_MAKE: $("${GNU_MAKE}" --version)"
echo "GREP_VERSION: $(grep --version)"

################################################################################
# Install the host compiler
################################################################################

if [ "$D_COMPILER" == "dmd" ]; then
    install_host_dmd
elif [ "$D_COMPILER" == "ldc" ]; then
    install_host_ldc
    # we still need DigitalMars make :/
    install_dm_make
else
    echo 'Invalid $D_COMPILER provided'.
    exit 1
fi

echo "HOST_DC: $("${HOST_DC}" --version)"
echo "DM_MAKE: $(! "${DM_MAKE}" --version)" # DM_MAKE doesn't have a --version flag, but this prints its version

################################################################################
# Checkout other repositories
################################################################################

REPO_BRANCH="$SYSTEM_PULLREQUEST_TARGETBRANCH"

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

################################################################################
# Prepare build flags
################################################################################

export CC="${MSVC_CC}"
export AR="${MSVC_AR}"

if [ "$MODEL" == "64" ] ; then
    export MODEL_FLAG="-m64"
    MAKE_FILE="win64.mak"
else
    export MODEL_FLAG="-m32"
    MAKE_FILE="win32.mak"
fi

################################################################################
# WORKAROUND: Make the paths to CC and AR whitespace free
# REASON: Druntime & Phobos Makefiles as the variables don't use quotation
################################################################################

ln -s "$(dirname "$CC")" "${DMD_DIR}/../ccdir"
export CC="$DMD_DIR/../ccdir/cl.exe"
export AR="$DMD_DIR/../ccdir/lib.exe"

################################################################################
# Build DMD
################################################################################

DMD_BIN_PATH="$DMD_DIR/generated/windows/release/${MODEL}/dmd"

cd "${DMD_DIR}/src"
"${DM_MAKE}" -f "${MAKE_FILE}" reldmd DMD="$DMD_BIN_PATH" HOST_DC="${HOST_DC}" CC="${CC}"

################################################################################
# WORKAROUND: Build zlib separately with DigitalMars make
# REASON: whitespace path variables in DigitalMars make from indirect invocation from Phobos
################################################################################

cd "${DMD_DIR}/../phobos/etc/c/zlib"
${DM_MAKE} -f win64.mak "MODEL=${MODEL}" "zlib${MODEL}.lib" CC="${CC}" LIB="${AR}" VCDIR="${VCINSTALLDIR}"

################################################################################
# Build Druntime and Phobos
################################################################################

for proj in druntime phobos; do
    cd "${DMD_DIR}/../${proj}"
    "${DM_MAKE}" -f "${MAKE_FILE}" DMD="$DMD_BIN_PATH" CC="$CC" AR="$MSVC_AR" VCDIR="${VCINSTALLDIR}" CFLAGS="/C7"
done

################################################################################
# Run DMD testsuite
################################################################################
cd "${DMD_DIR}/test"

# WORKAROUND: Copy the built Phobos library in the path
# REASON: LIB argument doesn't seem to work
cp "${DMD_DIR}/../phobos/phobos64.lib" .

DMD_TESTSUITE_MAKE_ARGS="-j$N" "${GNU_MAKE}" -j1 all ARGS="-O -inline -g" MODEL="$MODEL"  MODEL_FLAG="$MODEL_FLAG"

################################################################################
# Prepare artifacts
################################################################################

mkdir -p "${DMD_DIR}/artifacts"
cd "${DMD_DIR}/artifacts"
cp "${DMD_DIR}/../phobos/phobos64.lib" .
cp "${DMD_BIN_PATH}" .
