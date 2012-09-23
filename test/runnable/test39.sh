#!/usr/bin/env bash

dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable
log_file=${dir}/test39.sh.log

rm -f ${log_file}

$DMD -m${MODEL} -Irunnable -od${dmddir} -c runnable/extra-files/test39.d >> ${log_file}
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

$DMD -m${MODEL} -Irunnable -od${dmddir} -c runnable/imports/test39a.d >> ${log_file}
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

if [ ${OS} == "win32" ]; then
    lib -c ${dmddir}${SEP}test39a.lib ${dmddir}${SEP}test39a.obj >> ${log_file} 2>&1
    LIBEXT=.lib
else
    ar -r ${dir}/test39a.a ${dir}/test39a.o >> ${log_file} 2>&1
    LIBEXT=.a
fi
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

$DMD -m${MODEL} -of${dmddir}${SEP}test39 ${dir}/test39${OBJ} ${dir}/test39a${LIBEXT} >> ${log_file}
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

./${dir}/test39 >> ${log_file}
if [ $? -ne 0 ]; then
    cat ${log_file}
    rm -f ${log_file}
    exit 1
fi

rm ${dir}/{test39${OBJ},test39a${OBJ},test39a${LIBEXT},test39${EXE}}

