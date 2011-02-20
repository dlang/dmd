#!/usr/bin/env bash

dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test35.sh.out

rm -f ${output_file}

$DMD -m${MODEL} -Irunnable -od${dmddir} -c runnable/extra-files/test35.d >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

$DMD -m${MODEL} -od${dmddir} -c -release runnable/imports/test35a.d >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

$DMD -m${MODEL} -of${dmddir}${SEP}test35 ${dir}/test35${OBJ} ${dir}/test35a${OBJ} >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

./${dir}/test35 >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

rm ${dir}/{test35${OBJ},test35a${OBJ},test35${EXE}}

