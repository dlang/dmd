#!/usr/bin/env bash

dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test39.sh.out

rm -f ${output_file}

$DMD -m${MODEL} -Irunnable -od${dmddir} -c runnable/extra-files/test39.d >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

$DMD -m${MODEL} -Irunnable -od${dmddir} -c runnable/imports/test39a.d >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

if [ ${OS} == "win32" -o ${OS} == "win64" ]; then
    $DMD -m${MODEL} -lib -of${dmddir}${SEP}test39a.lib ${dmddir}${SEP}test39a.obj >> ${output_file} 2>&1
else
    ar -r ${dir}/test39a.a ${dir}/test39a.o >> ${output_file} 2>&1
fi
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

$DMD -m${MODEL} -of${dmddir}${SEP}test39${EXE} ${dir}/test39${OBJ} ${dir}/test39a${LIBEXT} >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

${dir}/test39 >> ${output_file}
if [ $? -ne 0 ]; then
    cat ${output_file}
    rm -f ${output_file}
    exit 1
fi

rm ${dir}/{test39${OBJ},test39a${OBJ},test39a${LIBEXT},test39${EXE}}

