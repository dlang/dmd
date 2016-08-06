#!/bin/bash

set -uexo pipefail

# add missing cc link in gdc-4.9.3 download
if [ $DC = gdc ] && [ ! -f $(dirname $(which gdc))/cc ]; then
    ln -s gcc $(dirname $(which gdc))/cc
fi
N=2

git clone --depth=1 --branch $TRAVIS_BRANCH https://github.com/D-Programming-Language/druntime.git ../druntime
git clone --depth=1 --branch $TRAVIS_BRANCH https://github.com/D-Programming-Language/phobos.git ../phobos

# build dmd, druntime, phobos
build() {
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD all
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD dmd.conf
    make -j$N -C ../druntime -f posix.mak MODEL=$MODEL
    make -j$N -C ../phobos -f posix.mak MODEL=$MODEL
}

# self-compile dmd
rebuild() {
    mv src/dmd src/host_dmd
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=./host_dmd clean
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=./host_dmd dmd.conf
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=./host_dmd all
}

# test druntime, phobos, dmd
test() {
    make -j$N -C ../druntime -f posix.mak MODEL=$MODEL unittest
    make -j$N -C ../phobos -f posix.mak MODEL=$MODEL unittest
    test_dmd
}

# test dmd
test_dmd() {
    # test fewer compiler argument permutations for PRs to reduce CI load
    if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then
        make -j$N -C test MODEL=$MODEL # all ARGS by default
    else
        make -j$N -C test MODEL=$MODEL ARGS="-O -inline -release"
    fi
}

build
test
rebuild
rebuild
test_dmd
