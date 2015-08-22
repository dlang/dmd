#!/bin/bash

set -exo pipefail

N=2

make -j$N -C src -f posix.mak ddmd HOST_DMD=$DMD
make -j$N -C src -f posix.mak dmd.conf
git clone --depth=1 https://github.com/D-Programming-Language/druntime.git ../druntime
git clone --depth=1 https://github.com/D-Programming-Language/phobos.git ../phobos
make -j$N -C ../druntime -f posix.mak DMD=../dmd/src/ddmd
make -j$N -C ../phobos -f posix.mak DMD=../dmd/src/ddmd

make -j$N -C ../druntime -f posix.mak DMD=../dmd/src/ddmd unittest
make -j$N -C ../phobos -f posix.mak DMD=../dmd/src/ddmd unittest
make -j$N -C test DMD=../src/ddmd MODEL=64
