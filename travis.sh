#!/bin/bash

set -exo pipefail

make -C src -f posix.mak ddmd HOST_DMD=$DMD
make -C src -f posix.mak dmd.conf
git clone --depth=1 https://github.com/D-Programming-Language/druntime.git ../druntime
git clone --depth=1 https://github.com/D-Programming-Language/phobos.git ../phobos
make -C ../druntime -f posix.mak DMD=../dmd/src/ddmd
make -C ../phobos -f posix.mak DMD=../dmd/src/ddmd

make -C ../druntime -f posix.mak DMD=../dmd/src/ddmd unittest
make -C ../phobos -f posix.mak DMD=../dmd/src/ddmd unittest
make -C test DMD=../src/ddmd MODEL=64
