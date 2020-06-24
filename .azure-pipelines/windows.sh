#!/bin/sh

set -eux -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR"/lib.sh

GNU_MAKE="$(which make)"

################################################################################
# Setup required tools
################################################################################

# WORKAROUND: install a newer grep version
# REASON: the preinstalled version is buggy (see also: https://github.com/dlang/dmd/pull/9398#issuecomment-468773638)
install_grep

if [ "$HOST_DMD_VERSION" == "LATEST" ]; then
    download "http://downloads.dlang.org/releases/LATEST" LATEST
    HOST_DMD_VERSION="$(cat LATEST)"
fi
echo "D_VERSION: $HOST_DMD_VERSION"
echo "VSINSTALLDIR: $VSINSTALLDIR"
echo "GNU_MAKE: $("${GNU_MAKE}" --version)"
echo "GREP_VERSION: $(grep --version)"

################################################################################
# Prepare C compiler
################################################################################

if [ "$MODEL" == "32" ] ; then
    install_host_dmc
    export CC="$PWD/dm/bin/dmc.exe"
    export AR="$PWD/dm/bin/lib.exe"
else
    export CC="$(where cl.exe)"
    export AR="$(where lib.exe)" # must be done before installing dmd
    export MSVC_AR="$AR"         # for msvc-lib
fi

################################################################################
# Install the host compiler
################################################################################

if [ "$D_COMPILER" == "dmd" ]; then
    install_host_dmd
else
    echo 'Invalid $D_COMPILER provided'.
    exit 1
fi

################################################################################
# Checkout other repositories
################################################################################

clone_repos

################################################################################
# Prepare build flags
################################################################################

if [ "$MODEL" == "64" ] ; then
    export MODEL_FLAG="-m64"
    MAKE_FILE="win64.mak"
    LIBNAME=phobos64.lib
elif [ "$MODEL" == "32mscoff" ] ; then
    export MODEL_FLAG="-m32mscoff"
    MAKE_FILE="win64.mak"
    LIBNAME=phobos32mscoff.lib
else
    export MODEL_FLAG="-m32"
    export LIB="$PWD/dmd2/windows/lib"
    MAKE_FILE="win32.mak"
    LIBNAME=phobos.lib
fi

################################################################################
# Build DMD
################################################################################

DMD_BIN_PATH="$DMD_DIR/generated/windows/release/${MODEL}/dmd"

cd "${DMD_DIR}/src"
"${DM_MAKE}" -f "${MAKE_FILE}" reldmd DMD="$DMD_BIN_PATH"

################################################################################
# WORKAROUND: Build zlib separately with DigitalMars make
# REASON: whitespace path variables in DigitalMars make from indirect invocation from Phobos
################################################################################

if [ "$MODEL" != "32" ] ; then
    cd "${DMD_DIR}/../phobos/etc/c/zlib"
    ${DM_MAKE} -f win64.mak MODEL=${MODEL} "zlib${MODEL}.lib" "CC=$CC" "LIB=$AR" VCDIR=.
fi

################################################################################
# Build Druntime and Phobos
################################################################################

for proj in druntime phobos; do
    cd "${DMD_DIR}/../${proj}"
    "${DM_MAKE}" -f "${MAKE_FILE}" MODEL=$MODEL DMD="$DMD_BIN_PATH" "CC=$CC" "AR=$AR" VCDIR=.
done

################################################################################
# Run druntime tests
################################################################################
cd "${DMD_DIR}/../druntime"
"${DM_MAKE}" -f "${MAKE_FILE}" MODEL=$MODEL DMD="$DMD_BIN_PATH" "CC=$CC" "AR=$AR" VCDIR=. unittest test_all

################################################################################
# Run DMD testsuite
################################################################################
cd "${DMD_DIR}/test"

if [ "$MODEL" == "32" ] ; then
    # Prebuild some tools (run & d_do_test, built by Makefile) with host compiler.
    "${GNU_MAKE}" -j1 test_results/run.exe MODEL="$MODEL" MODEL_FLAG="$MODEL_FLAG" N="$N"
    # WORKAROUND: Make Optlink use freshly built Phobos, not the host compiler's.
    # Optlink apparently prefers LIB in sc.ini over the LIB env variable (and `-conf=` for
    # DMD apparently doesn't prevent that).
    #rm "$LIB/../bin/sc.ini"
    cp "${DMD_DIR}/../phobos/$LIBNAME" .
    # This also requires to build the remaining tools (sanitize_json & unit_test_runner,
    # built by run.d, not the Makefile...) with the tested compiler, not the host compiler.
    "${GNU_MAKE}" -j1 start_all_tests ARGS="-O -inline -g" MODEL="$MODEL" MODEL_FLAG="$MODEL_FLAG" N="$N" HOST_DMD="$DMD_BIN_PATH"
else
    "${GNU_MAKE}" -j1 start_all_tests ARGS="-O -inline -g" MODEL="$MODEL" MODEL_FLAG="$MODEL_FLAG" N="$N"
fi

################################################################################
# Prepare artifacts
################################################################################

mkdir -p "${DMD_DIR}/artifacts"
cd "${DMD_DIR}/artifacts"
cp "${DMD_DIR}/../phobos/$LIBNAME" .
cp "${DMD_BIN_PATH}" .
