#!/bin/sh

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
    download "http://downloads.dlang.org/releases/LATEST" LATEST
    HOST_DMD_VERSION="$(cat LATEST)"
fi
echo "D_VERSION: $HOST_DMD_VERSION"
echo "VSINSTALLDIR: $VSINSTALLDIR"
echo "GREP_VERSION: $(grep --version)"

################################################################################
# Prepare DigitalMars make and C compiler
################################################################################

install_host_dmc
DM_MAKE="$PWD/dm/bin/make.exe"

if [ "$MODEL" == "32" ] ; then
    CC="$PWD/dm/bin/dmc.exe"
    AR="$PWD/dm/bin/lib.exe"
else
    CC="$(where cl.exe)"
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
elif [ "$MODEL" == "32mscoff" ] ; then
    MAKE_FILE="win64.mak"
    LIBNAME=phobos32mscoff.lib
else
    export LIB="$PWD/dmd2/windows/lib"
    MAKE_FILE="win32.mak"
    LIBNAME=phobos.lib
fi

################################################################################
# Build DMD (incl. building and running the unittests)
################################################################################

DMD_BIN_PATH="$DMD_DIR/generated/windows/release/$MODEL/dmd"

cd "$DMD_DIR/src"
"$DM_MAKE" -f "$MAKE_FILE" MAKE="$DM_MAKE" BUILD=debug unittest
DFLAGS="-L-LARGEADDRESSAWARE" "$DM_MAKE" -f "$MAKE_FILE" MAKE="$DM_MAKE" reldmd-asserts

################################################################################
# Build Druntime and Phobos
################################################################################

LIBS_MAKE_ARGS=(-f "$MAKE_FILE" MODEL=$MODEL DMD="$DMD_BIN_PATH" VCDIR=. CC="$CC" AR="$AR" MAKE="$DM_MAKE")

for proj in druntime phobos; do
    cd "$DMD_DIR/../$proj"
    "$DM_MAKE" "${LIBS_MAKE_ARGS[@]}"
done

################################################################################
# Build and run druntime tests
################################################################################

cd "$DMD_DIR/../druntime"
"$DM_MAKE" "${LIBS_MAKE_ARGS[@]}" unittest test_all

################################################################################
# Run DMD testsuite
################################################################################

cd "$DMD_DIR/test"

# build run.d testrunner and its tools while host compiler is untampered
cd ../test
"$HOST_DC" -m$MODEL -g -i run.d
./run tools

if [ "$MODEL" == "32" ] ; then
    # WORKAROUND: Make Optlink use freshly built Phobos, not the host compiler's.
    # Optlink apparently prefers LIB in sc.ini over the LIB env variable (and
    # `-conf=` for DMD apparently doesn't prevent that, and there's apparently
    # no sane way to specify a libdir for Optlink in the DMD cmdline).
    rm "$DMD_DIR/tools/dmd2/windows/bin/sc.ini"
fi

targets=("all")
args=('ARGS=-O -inline -g') # no -release for faster builds
if [ "$HOST_DMD_VERSION" = "2.079.0" ] ; then
    # skip runnable_cxx and unit_tests with older bootstrap compilers
    targets=("runnable" "compilable" "fail_compilation" "dshell")
    args=() # use default set of args
fi
CC="$CC" ./run --environment --jobs=$N "${targets[@]}" "${args[@]}"

################################################################################
# Build and run Phobos unittests
################################################################################

if [ "$MODEL" = "32" ] ; then
    echo "FIXME: cannot compile 32-bit OMF Phobos unittests ('more than 32767 symbols in object file')"
else
    cd "$DMD_DIR/../phobos"
    if [ "$MODEL" = "64" ] ; then
        cp "$DMD_DIR/tools/dmd2/windows/bin64/libcurl.dll" .
    else
        cp "$DMD_DIR/tools/dmd2/windows/bin/libcurl.dll" .
    fi
    "$DM_MAKE" "${LIBS_MAKE_ARGS[@]}" unittest
fi

################################################################################
# Prepare artifacts
################################################################################

mkdir -p "$DMD_DIR/artifacts"
cd "$DMD_DIR/artifacts"
cp "$DMD_DIR/../phobos/$LIBNAME" .
cp "$DMD_BIN_PATH" .
