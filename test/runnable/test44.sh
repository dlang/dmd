#!/usr/bin/env bash

dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable
log_file=${dir}/test44.sh.log

rm -f ${log_file}

$DMD -m${MODEL} -Irunnable -od${dmddir} -of${dmddir}${SEP}test44_1 runnable/extra-files/test44.d runnable/imports/test44a.d >> ${log_file}
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

./${dir}/test44_1 >> ${log_file}
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

$DMD -m${MODEL} -Irunnable -od${dmddir} -of${dmddir}${SEP}test44_2 runnable/imports/test44a.d runnable/extra-files/test44.d >> ${log_file}
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

./${dir}/test44_2 >> ${log_file}
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

rm ${dir}/{test44_1${OBJ},test44_1${EXE},test44_2${OBJ},test44_2${EXE}}

