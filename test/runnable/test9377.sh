#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test9377.sh.out

libname=${dir}${SEP}lib9377${LIBEXT}

$DMD -m${MODEL} -I${src} -of${libname} -c ${src}${SEP}mul9377a.d ${src}${SEP}mul9377b.d -lib || exit 1
$DMD -m${MODEL} -I${src} -of${dir}${SEP}mul9377${EXE} ${src}${SEP}multi9377.d ${libname} || exit 1

rm ${dir}/{lib9377${LIBEXT},mul9377${OBJ},mul9377${EXE}}

echo Success >${output_file}
