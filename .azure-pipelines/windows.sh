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

GNU_MAKE="$(which make)" # must be done before installing dmd (tampers with PATH)
install_host_dmc
DM_MAKE="$PWD/dm/bin/make.exe"

if [ "$MODEL" == "32omf" ] ; then
    CC="$PWD/dm/bin/dmc.exe"
    AR="$PWD/dm/bin/lib.exe"
    export CPPCMD="$PWD/dm/bin/sppn.exe"
else
    CC="cl.exe"
    AR="$(where lib.exe)" # must be done before installing dmd
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
    MAKE_FILE="win64.mak"
    LIBNAME=phobos64.lib
elif [ "$MODEL" == "32" ] ; then
    MAKE_FILE="win64.mak"
    LIBNAME=phobos32mscoff.lib
else # 32omf
    MAKE_FILE="win32.mak"
    LIBNAME=phobos.lib
fi

################################################################################
# Build DMD (incl. building and running the unittests)
################################################################################

# no `-debug` for unittests build with old host compilers (to avoid compile errors)
disable_debug_for_unittests=()
if [[ "$HOST_DMD_VERSION" == "2.079.0" ]]; then
    disable_debug_for_unittests=(ENABLE_DEBUG=0)
fi

# avoid the DMC runtime and its limitations for the compiler and {build,run}.d tools themselves
TOOL_MODEL="$MODEL"
if [[ "$MODEL" == "32omf" ]]; then
    TOOL_MODEL=32
fi

cd "$DMD_DIR"
"$HOST_DC" -m$TOOL_MODEL compiler/src/build.d -ofgenerated/build.exe
generated/build.exe -j$N MODEL=$TOOL_MODEL HOST_DMD=$HOST_DC BUILD=debug "${disable_debug_for_unittests[@]}" unittest
generated/build.exe -j$N MODEL=$TOOL_MODEL HOST_DMD=$HOST_DC DFLAGS="-L-LARGEADDRESSAWARE" ENABLE_RELEASE=1 ENABLE_ASSERTS=1 dmd

DMD_BIN_PATH="$DMD_DIR/generated/windows/release/$TOOL_MODEL/dmd.exe"

################################################################################
# Build Druntime and Phobos
################################################################################

LIBS_MAKE_ARGS=(-f "$MAKE_FILE" MODEL=$MODEL DMD="$DMD_BIN_PATH" VCDIR=. CC="$CC" AR="$AR" MAKE="$DM_MAKE")

"$GNU_MAKE" -j$N -C "$DMD_DIR/druntime" MODEL=$MODEL DMD="$DMD_BIN_PATH"

cd "$DMD_DIR/../phobos"
"$DM_MAKE" "${LIBS_MAKE_ARGS[@]}" DRUNTIME="$DMD_DIR\druntime" DRUNTIMELIB="$DMD_DIR/generated/windows/release/$MODEL/druntime.lib"
if [[ "$MODEL" == "32" ]]; then
    # the expected Phobos filename for 32-bit COFF is phobos32mscoff.lib, not phobos32.lib
    mv phobos32.lib phobos32mscoff.lib
fi

################################################################################
# Run DMD testsuite
################################################################################

cd "$DMD_DIR/compiler/test"

# Rebuild dmd with ENABLE_COVERAGE for coverage tests
if [ "${DMD_TEST_COVERAGE:-0}" = "1" ] ; then

    # Recompile debug dmd + unittests
    rm -rf "$DMD_DIR/generated/windows"
    ../../generated/build.exe -j$N MODEL=$TOOL_MODEL DFLAGS="-L-LARGEADDRESSAWARE" ENABLE_DEBUG=1 ENABLE_COVERAGE=1 dmd
    ../../generated/build.exe -j$N MODEL=$TOOL_MODEL DFLAGS="-L-LARGEADDRESSAWARE" ENABLE_DEBUG=1 ENABLE_COVERAGE=1 unittest
fi

"$HOST_DC" -m$TOOL_MODEL -g -i run.d

if [ "$MODEL" == "32omf" ] ; then
    # Pre-build the tools while the host compiler's sc.ini is untampered (see below).
    ./run tools

    # WORKAROUND: Make Optlink use freshly built Phobos, not the host compiler's.
    # Optlink apparently prefers LIB in sc.ini (in the same dir as optlink.exe)
    # over the LIB env variable (and `-conf=` for DMD apparently doesn't prevent
    # that, and there's apparently no sane way to specify a libdir for Optlink
    # in the DMD cmdline either).
    rm "$DMD_DIR/tools/dmd2/windows/bin/sc.ini"
    # We also need to remove LIB from the freshly built compiler's sc.ini -
    # not all test invocations use `-conf=`.
    sed -i 's|^LIB=.*$||g' "$DMD_DIR/generated/windows/release/$TOOL_MODEL/sc.ini"
    # Okay, now the lib directories are controlled by the LIB env variable.
    # run.d prepends the dir containing freshly built phobos.lib; we still need
    # the DMC and Windows libs from the host compiler.
    export LIB="$DMD_DIR/tools/dmd2/windows/lib"
fi

targets=("all")
args=('ARGS=-O -inline -g') # no -release for faster builds
if [ "$HOST_DMD_VERSION" = "2.079.0" ] ; then
    # skip runnable_cxx and unit_tests with older bootstrap compilers
    targets=("runnable" "compilable" "fail_compilation" "dshell")
    args=() # use default set of args
fi
./run --environment --jobs=$N "${targets[@]}" "${args[@]}" CC="$CC"

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

################################################################################
# Build and run Phobos unittests
################################################################################

if [ "$MODEL" = "32omf" ] ; then
    echo "FIXME: cannot compile 32-bit OMF Phobos unittests ('more than 32767 symbols in object file')"
else
    cd "$DMD_DIR/../phobos"
    if [ "$MODEL" = "64" ] ; then
        cp "$DMD_DIR/tools/dmd2/windows/bin64/libcurl.dll" .
    else
        cp "$DMD_DIR/tools/dmd2/windows/bin/libcurl.dll" .
    fi
    "$DM_MAKE" "${LIBS_MAKE_ARGS[@]}" DRUNTIME="$DMD_DIR\druntime" DRUNTIMELIB="$DMD_DIR/generated/windows/release/$MODEL/druntime.lib" unittest
fi

################################################################################
# Prepare artifacts
################################################################################

mkdir -p "$DMD_DIR/artifacts"
cd "$DMD_DIR/artifacts"
cp "$DMD_DIR/../phobos/$LIBNAME" .
cp "$DMD_BIN_PATH" .
