#!/bin/bash

set -uexo pipefail

N=${N:-2}

make -j${N} -f posix.mak

# rebuild dmd with coverage enabled
# use the just built dmd as host compiler this time
build_path="generated/linux/release/$MODEL"
host_dmd="_${build_path}/host_dmd"
host_dmd_cov="${host_dmd}_cov"

# `generated` gets cleaned in the next step, so we create another _generated
# The nested folder hierarchy is needed to conform to those specified in
# the generate dmd.conf
mkdir -p _"${build_path}"
cp "$build_path/dmd" _"$host_dmd"
cp "$build_path/dmd.conf" "_${build_path}"

make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD="../$host_dmd" PIC="$PIC" clean
make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD="../$host_dmd" ENABLE_COVERAGE=1 ENABLE_WARNINGS=1 PIC="$PIC"

# copy currently build dmd to avoid it being overwritten later
cp "${build_path}/dmd" "${host_dmd_cov}"

# run the testsuite
make -j1 -C test MODEL=$MODEL ARGS="-O -inline -release" DMD_TEST_COVERAGE=1 PIC="$PIC"

# run the internal unittests
make -j1 -C src -f posix.mak MODEL=$MODEL HOST_DMD="${host_dmd_cov}" ENABLE_COVERAGE=1 PIC="$PIC" unittest

################################################################################
# Send to CodeCov
################################################################################

rm -rf ../test/runnable/extra-files
cd src # need to run from compilation folder for gcov to find sources
# must match g++ version
bash ../codecov.sh -p .. -x gcov-4.9 -t "${CODECOV_TOKEN}"
