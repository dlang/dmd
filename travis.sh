#!/bin/bash

set -exo pipefail

# add missing cc link in gdc-4.9.3 download
if [ $DC = gdc ] && [ ! -f $(dirname $(which gdc))/cc ]; then
    ln -s gcc $(dirname $(which gdc))/cc
fi
N=2

git clone --depth=1 --branch $TRAVIS_BRANCH https://github.com/D-Programming-Language/druntime.git ../druntime
git clone --depth=1 --branch $TRAVIS_BRANCH https://github.com/D-Programming-Language/phobos.git ../phobos

make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD all
make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD dmd.conf
make -j$N -C ../druntime -f posix.mak MODEL=$MODEL
make -j$N -C ../phobos -f posix.mak MODEL=$MODEL

while [ $SELF_COMPILE -gt 0 ]; do
    if [ $SELF_COMPILE -eq 1 ] && [ $DMD = "dmd" ] && ! [ -z "$SELF_DMD_TEST_COVERAGE" ] ; then
        echo "Building with coverage statistics"
        export DMD_TEST_COVERAGE=1
    fi

    # rebuild dmd using the just build dmd as host compiler
    mv src/dmd src/host_dmd
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=./host_dmd clean
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=./host_dmd dmd.conf
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=./host_dmd
    make -j$N -C ../druntime -f posix.mak MODEL=$MODEL clean
    make -j$N -C ../druntime -f posix.mak MODEL=$MODEL
    make -j$N -C ../phobos -f posix.mak MODEL=$MODEL clean
    make -j$N -C ../phobos -f posix.mak MODEL=$MODEL
    rm src/host_dmd
    SELF_COMPILE=$(($SELF_COMPILE - 1))
done

# Only run runtime + phobos tests on Travis
if [ "${CIRCLECI}" != "true" ] ; then
	make -j$N -C ../druntime -f posix.mak MODEL=$MODEL unittest
	make -j$N -C ../phobos -f posix.mak MODEL=$MODEL unittest
fi

QUICK_BUILD=0
if [ "$TRAVIS_PULL_REQUEST" == "false" ] ; then
	QUICK_BUILD=1
fi

# test fewer compiler argument permutations for PRs to reduce CI load
if [ $QUICK_BUILD -eq 1 ]; then
    make -j$N -C test MODEL=$MODEL
else
    make -j$N -C test MODEL=$MODEL ARGS="-O -inline -release"
fi
