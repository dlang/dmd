#!/bin/bash

set -exo pipefail

N=2

git clone --depth=1 https://github.com/D-Programming-Language/druntime.git ../druntime
git clone --depth=1 https://github.com/D-Programming-Language/phobos.git ../phobos

make -j$N -C src -f posix.mak HOST_DMD=$DMD all
make -j$N -C src -f posix.mak HOST_DMD=$DMD dmd.conf
make -j$N -C ../druntime -f posix.mak
make -j$N -C ../phobos -f posix.mak

# export path for shared phobos library
mkdir -p ../lib
export LD_LIBRARY_PATH="${PWD}/../lib:${LD_LIBRARY_PATH}"

while [ $SELF_COMPILE -gt 0 ]; do
    # copy shared phobos library
    cp ../phobos/generated/linux/release/64/libphobos2.so* ../lib/
    # rebuild dmd using the just build dmd as host compiler
    mv src/dmd src/host_dmd
    make -j$N -C src -f posix.mak HOST_DMD=./host_dmd clean
    make -j$N -C src -f posix.mak HOST_DMD=./host_dmd dmd.conf
    make -j$N -C src -f posix.mak HOST_DMD=./host_dmd
    make -j$N -C ../druntime -f posix.mak clean
    make -j$N -C ../druntime -f posix.mak
    make -j$N -C ../phobos -f posix.mak clean
    make -j$N -C ../phobos -f posix.mak
    rm src/host_dmd
    SELF_COMPILE=$(($SELF_COMPILE - 1))
done

make -j$N -C ../druntime -f posix.mak unittest
make -j$N -C ../phobos -f posix.mak unittest
# test fewer compiler argument permutations for PRs to reduce CI load
if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then
    make -j$N -C test MODEL=64
else
    make -j$N -C test MODEL=64 ARGS="-O -inline -release"
fi
