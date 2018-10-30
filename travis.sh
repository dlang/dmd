#!/bin/bash

set -exo pipefail

VERSION=dmd-cxx
N=2

## build dmd.
make -j$N -C src -f posix.mak dmd HOST_CC="$CXX"
make -j$N -C src -f posix.mak dmd.conf

## build druntime and phobos.
git clone --depth=1 --branch=$VERSION https://github.com/dlang/druntime.git ../druntime
git clone --depth=1 --branch=$VERSION https://github.com/dlang/phobos.git ../phobos
make -j$N -C ../druntime -f posix.mak DMD=../dmd/src/dmd
make -j$N -C ../phobos -f posix.mak DMD=../dmd/src/dmd

## run unittest and testsuite.
make -j$N -C ../druntime -f posix.mak DMD=../dmd/src/dmd unittest
#make -j$N -C ../phobos -f posix.mak DMD=../dmd/src/dmd unittest
#make -j$N -C test DMD=../src/dmd MODEL=64

## build dmd master
# Can't do anymore because of dependency on -mv
#git clone --depth=1 https://github.com/dlang/dmd.git ../dmd-master
#make -j$N -C ../dmd-master -f posix.mak HOST_DMD=../../dmd/src/dmd
