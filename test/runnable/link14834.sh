#!/usr/bin/env bash


src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable

libname=${dir}${SEP}link14834${LIBEXT}
exename=${dir}${SEP}link14834${EXE}

$DMD -m${MODEL} -I${src} -lib           -of${libname} ${src}${SEP}link14834a.d
$DMD -m${MODEL} -I${src} -inline -debug -of${exename} ${src}${SEP}link14834b.d ${libname}

${dir}/link14834

rm ${libname} ${exename} ${dir}${SEP}link14834${OBJ}
