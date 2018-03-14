#!/usr/bin/env bash



if [ ${OS} != "linux" ]; then
    echo "Skipping shared library test on ${OS}."
    exit 0
fi

$DMD -m${MODEL} -of${OUTPUT_BASE}${EXE} -defaultlib=libphobos2.so ${EXTRA_FILES}${SEP}test_shared.d

LD_LIBRARY_PATH=../../phobos/generated/${OS}/release/${MODEL} ${OUTPUT_BASE}${EXE}
