#!/bin/bash

dir=${RESULTS_DIR}/runnable
output_file=${dir}/test35.sh.out

rm -f ${output_file}

$DMD -Irunnable -od${dir} -c runnable/extra-files/test35.d >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

$DMD -od${dir} -c -release runnable/imports/test35a.d >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

$DMD -of${dir}/test35 ${dir}/test35.o ${dir}/test35a.o >> ${output_file}
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

rm ${dir}/{test35.o,test35a.o,test35}

