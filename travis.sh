#!/bin/bash

set -exo pipefail

N=2

make -j$N -C src -f posix.mak HOST_DMD=$DMD
make -j$N -C src -f posix.mak dmd.conf HOST_DMD=$DMD
git clone --depth=1 https://github.com/D-Programming-Language/druntime.git ../druntime
git clone --depth=1 https://github.com/D-Programming-Language/phobos.git ../phobos
make -j$N -C ../druntime -f posix.mak
make -j$N -C ../phobos -f posix.mak

make -j$N -C ../druntime -f posix.mak unittest
make -j$N -C ../phobos -f posix.mak unittest
make -j$N -C test MODEL=64
