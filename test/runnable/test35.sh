#!/usr/bin/env bash

set -e

dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable

$DMD -m${MODEL} -Irunnable -od${dmddir} -c runnable/extra-files/test35.d

$DMD -m${MODEL} -od${dmddir} -c -release runnable/imports/test35a.d

$DMD -m${MODEL} -of${dmddir}${SEP}test35${EXE} ${dir}/test35${OBJ} ${dir}/test35a${OBJ}

${dir}/test35

rm ${dir}/{test35${OBJ},test35a${OBJ},test35${EXE}}
