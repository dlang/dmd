#!/bin/bash

dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test44.sh.out

rm -f ${output_file}

$DMD -Irunnable -od${dmddir} -of${dmddir}${SEP}test44 runnable/extra-files/test44.d runnable/imports/test44a.d >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

./${dir}/test44 >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

$DMD -Irunnable -od${dmddir} -of${dmddir}${SEP}test44 runnable/imports/test44a.d runnable/extra-files/test44.d >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

./${dir}/test44 >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

rm ${dir}/{test44${OBJ},test44${EXE}}

