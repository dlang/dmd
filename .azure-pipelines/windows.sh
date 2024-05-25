#!/bin/bash

set -eux -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "$DIR/lib.sh"

################################################################################
# Setup required tools
################################################################################

# WORKAROUND: install a newer grep version
# REASON: the preinstalled version is buggy (see also: https://github.com/dlang/dmd/pull/9398#issuecomment-468773638)
install_grep

if [ "$HOST_DMD_VERSION" == "LATEST" ]; then
    download "https://downloads.dlang.org/releases/LATEST" LATEST
    HOST_DMD_VERSION="$(cat LATEST)"
fi
echo "D_VERSION: $HOST_DMD_VERSION"
echo "VSINSTALLDIR: $VSINSTALLDIR"
echo "GREP_VERSION: $(grep --version)"

################################################################################
# Prepare DigitalMars make and C compiler
################################################################################

GNU_MAKE="$(which make)" # must be done before installing dmc (tampers with PATH)

CC="cl.exe"
CXX="cl.exe"

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
    LIBNAME=phobos64.lib
elif [ "$MODEL" == "32" ] ; then
    LIBNAME=phobos32mscoff.lib
else
    echo 'Invalid $MODEL provided'.
    exit 1
fi

################################################################################
# Build DMD (incl. building and running the unittests)
################################################################################

# no `-debug` for unittests build with old host compilers (to avoid compile errors)
disable_debug_for_unittests=()
if [[ "$HOST_DMD_VERSION" == "2.079.0" ]]; then
    disable_debug_for_unittests=(ENABLE_DEBUG=0)
fi

cd "$DMD_DIR"
"$HOST_DC" -m$MODEL compiler/src/build.d -ofgenerated/build.exe
generated/build.exe -j$N MODEL=$MODEL HOST_DMD=$HOST_DC BUILD=debug "${disable_debug_for_unittests[@]}" unittest
generated/build.exe -j$N MODEL=$MODEL HOST_DMD=$HOST_DC DFLAGS="-L-LARGEADDRESSAWARE" ENABLE_RELEASE=1 ENABLE_ASSERTS=1 dmd

DMD_BIN_PATH="$DMD_DIR/generated/windows/release/$MODEL/dmd.exe"

################################################################################
# Build Druntime and Phobos
################################################################################

"$GNU_MAKE" -j$N -C "$DMD_DIR/druntime" MODEL=$MODEL DMD="$DMD_BIN_PATH"

"$GNU_MAKE" -j$N -C "$DMD_DIR/../phobos" MODEL=$MODEL DMD="$DMD_BIN_PATH" CC="$CC" DMD_DIR="$DMD_DIR"

################################################################################
# Run DMD testsuite
################################################################################

cd "$DMD_DIR/compiler/test"

# Rebuild dmd with ENABLE_COVERAGE for coverage tests
if [ "${DMD_TEST_COVERAGE:-0}" = "1" ] ; then

    # Recompile debug dmd + unittests
    rm -rf "$DMD_DIR/generated/windows"
    ../../generated/build.exe -j$N MODEL=$MODEL DFLAGS="-L-LARGEADDRESSAWARE" ENABLE_DEBUG=1 ENABLE_COVERAGE=1 dmd
    ../../generated/build.exe -j$N MODEL=$MODEL DFLAGS="-L-LARGEADDRESSAWARE" ENABLE_DEBUG=1 ENABLE_COVERAGE=1 unittest
fi

"$HOST_DC" -m$MODEL -g -i run.d

targets=("all")
args=('ARGS=-O -inline -g') # no -release for faster builds
if [ "$HOST_DMD_VERSION" = "2.079.0" ] ; then
    # skip runnable_cxx and unit_tests with older bootstrap compilers
    targets=("runnable" "compilable" "fail_compilation" "dshell")
    args=() # use default set of args
fi
./run --environment --jobs=$N "${targets[@]}" "${args[@]}" CC="$CC" CXX="$CXX"

###############################################################################
# Upload coverage reports and exit if ENABLE_COVERAGE is specified
################################################################################

if [ "${DMD_TEST_COVERAGE:-0}" = "1" ] ; then
    # Skip druntime & phobos tests
    exit 0
fi

################################################################################
# Build and run druntime tests
################################################################################

cd "$DMD_DIR/druntime"
"$GNU_MAKE" -j$N MODEL=$MODEL DMD="$DMD_BIN_PATH" CC="$CC" unittest

# run some tests for shared druntime

# no separate output for static or shared builds, so clean directories to force rebuild
rm -rf test/shared/generated
# the test_runner links against libdruntime-ut.dll and runs all unittests
#  no matter what module name is passed in, so restrict to src/object.d
"$GNU_MAKE" -j$N unittest MODEL=$MODEL SHARED=1 DMD="$DMD_BIN_PATH" CC="$CC" UT_SRCS=src/object.d ADDITIONAL_TESTS=test/shared

################################################################################
# Build and run Phobos unittests
################################################################################

cd "$DMD_DIR/../phobos"
if [ "$MODEL" = "64" ] ; then
    cp "$DMD_DIR/tools/dmd2/windows/bin64/libcurl.dll" .
else
    cp "$DMD_DIR/tools/dmd2/windows/bin/libcurl.dll" .
fi
"$GNU_MAKE" -j$N MODEL=$MODEL DMD="$DMD_BIN_PATH" CC="$CC" DMD_DIR="$DMD_DIR" unittest

################################################################################
# Prepare artifacts
################################################################################

mkdir -p "$DMD_DIR/artifacts"
cd "$DMD_DIR/artifacts"
cp "$DMD_DIR/../phobos/$LIBNAME" .
cp "$DMD_BIN_PATH" .
