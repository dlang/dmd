#!/usr/bin/env bash

dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test44.sh.out

rm -f ${output_file}

$DMD -m${MODEL} -Irunnable -od${dmddir} -of${dmddir}${SEP}test44_1${EXE} runnable/extra-files/test44.d runnable/imports/test44a.d >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

${dir}/test44_1 >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

$DMD -m${MODEL} -Irunnable -od${dmddir} -of${dmddir}${SEP}test44_2${EXE} runnable/imports/test44a.d runnable/extra-files/test44.d >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

${dir}/test44_2 >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

rm ${dir}/{test44_1${OBJ},test44_1${EXE},test44_2${OBJ},test44_2${EXE}}

