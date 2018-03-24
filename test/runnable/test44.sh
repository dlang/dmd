#!/usr/bin/env bash


dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable

$DMD -m${MODEL} -Irunnable -od${dmddir} -of${dmddir}${SEP}test44_1${EXE} runnable/extra-files/test44.d runnable/imports/test44a.d

${dir}/test44_1

$DMD -m${MODEL} -Irunnable -od${dmddir} -of${dmddir}${SEP}test44_2${EXE} runnable/imports/test44a.d runnable/extra-files/test44.d

${dir}/test44_2

rm ${dir}/{test44_1${OBJ},test44_1${EXE},test44_2${OBJ},test44_2${EXE}}
