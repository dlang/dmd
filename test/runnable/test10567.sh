#!/usr/bin/env bash


src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable

$DMD -m${MODEL} -I${src} -of${dir}${SEP}test10567a${OBJ} -c ${src}${SEP}test10567a.d
$DMD -m${MODEL} -I${src} -of${dir}${SEP}test10567${EXE} ${src}${SEP}test10567.d ${dir}${SEP}test10567a${OBJ}
${RESULTS_DIR}/runnable/test10567${EXE}

rm ${dir}/{test10567a${OBJ},test10567${EXE}}
