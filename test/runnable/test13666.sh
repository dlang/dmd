#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test13666.sh.out

libname=${dir}${SEP}lib13666${LIBEXT}

$DMD -m${MODEL} -I${src} -of${libname} -lib ${src}${SEP}lib13666.d || exit 1
$DMD -m${MODEL} -I${src} -of${dir}${SEP}test13666${EXE} ${src}${SEP}test13666.d ${libname} || exit 1

rm ${dir}/{lib13666${LIBEXT},test13666${OBJ},test13666${EXE}}

echo Success >${output_file}
