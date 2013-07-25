#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test10567.sh.out

$DMD -m${MODEL} -I${src} -of${dir}${SEP}test10567a${OBJ} -c ${src}${SEP}test10567a.d || exit 1
$DMD -m${MODEL} -I${src} -of${dir}${SEP}test10567${EXE} ${src}${SEP}test10567.d ${dir}${SEP}test10567a${OBJ} || exit 1
${RESULTS_DIR}/runnable/test10567${EXE} || exit 1

rm ${dir}/{test10567a${OBJ},test10567${EXE}}

echo Success >${output_file}
