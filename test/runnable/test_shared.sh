#!/usr/bin/env bash


dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable

if [ ${OS} != "linux" ]; then
    echo "Skipping shared library test on ${OS}."
    exit 0
fi

$DMD -m${MODEL} -of${dmddir}${SEP}test_shared${EXE} -defaultlib=libphobos2.so runnable/extra-files/test_shared.d

LD_LIBRARY_PATH=../../phobos/generated/${OS}/release/${MODEL} ${dmddir}${SEP}test_shared${EXE}
