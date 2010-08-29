#!/bin/bash

dir=${RESULTS_DIR}/runnable
output_file=${dir}/test39.sh.out

rm -f ${output_file}

$DMD -Irunnable -od${dir} -c runnable/extra-files/test39.d >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

$DMD -Irunnable -od${dir} -c runnable/imports/test39a.d >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

ar -r ${dir}/test39a.a ${dir}/test39a.o >> ${output_file} 2>&1
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

$DMD -of${dir}/test39 ${dir}/test39.o ${dir}/test39a.a >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

./${dir}/test39 >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

rm ${dir}/{test39.o,test39a.o,test39a.a,test39}

