#!/usr/bin/env bash

dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable
log_file=${dir}/test35.sh.log

rm -f ${log_file}

$DMD -m${MODEL} -Irunnable -od${dmddir} -c runnable/extra-files/test35.d >> ${log_file}
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

$DMD -m${MODEL} -od${dmddir} -c -release runnable/imports/test35a.d >> ${log_file}
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

$DMD -m${MODEL} -of${dmddir}${SEP}test35 ${dir}/test35${OBJ} ${dir}/test35a${OBJ} >> ${log_file}
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

./${dir}/test35 >> ${log_file}
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

rm ${dir}/{test35${OBJ},test35a${OBJ},test35${EXE}}

