#!/usr/bin/env bash

dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test_shared.sh.out

rm -f ${output_file}

if [ ${OS} != "linux" ]; then
    echo "Skipping shared library test on ${OS}."
    touch ${output_file}
    exit 0
fi

die()
{
    cat ${output_file}
    rm -f ${output_file}
    exit 1
}

$DMD -m${MODEL} -of${dmddir}${SEP}test_shared${EXE} -defaultlib=libphobos2.so runnable/extra-files/test_shared.d >> ${output_file}
if [ $? -ne 0 ]; then die; fi

LD_LIBRARY_PATH=../../phobos/generated/${OS}/release/${MODEL} ${dmddir}${SEP}test_shared${EXE}
if [ $? -ne 0 ]; then die; fi
