#!/usr/bin/env bash

set -e

dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable

$DMD -m${MODEL} -Irunnable -od${dmddir} -c runnable/extra-files/test39.d

$DMD -m${MODEL} -Irunnable -od${dmddir} -c runnable/imports/test39a.d

if [ ${OS} == "win32" -o ${OS} == "win64" ]; then
    $DMD -m${MODEL} -lib -of${dmddir}${SEP}test39a.lib ${dmddir}${SEP}test39a.obj  2>&1
else
    ar -r ${dir}/test39a.a ${dir}/test39a.o  2>&1
fi

$DMD -m${MODEL} -of${dmddir}${SEP}test39${EXE} ${dir}/test39${OBJ} ${dir}/test39a${LIBEXT}

${dir}/test39

rm ${dir}/{test39${OBJ},test39a${OBJ},test39a${LIBEXT},test39${EXE}}
