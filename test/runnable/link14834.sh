#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}${SEP}link14834.sh.out

rm -f ${output_file}

libname=${dir}${SEP}link14834${LIBEXT}
exename=${dir}${SEP}link14834${EXE}

$DMD -m${MODEL} -I${src} -lib           -of${libname} ${src}${SEP}link14834a.d            > ${output_file} || exit 1
$DMD -m${MODEL} -I${src} -inline -debug -of${exename} ${src}${SEP}link14834b.d ${libname} > ${output_file} || exit 1

${dir}/link14834 || exit 1

rm ${libname} ${exename} ${dir}${SEP}link14834${OBJ}

echo Success > ${output_file}
