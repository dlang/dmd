#!/usr/bin/env bash


src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable

libname=${dir}${SEP}libX${LIBEXT}

$DMD -m${MODEL} -I${src} -of${libname} -lib ${src}${SEP}linkdebug_uni.d ${src}${SEP}linkdebug_range.d ${src}${SEP}linkdebug_primitives.d

$DMD -m${MODEL} -I${src} -of${dir}${SEP}linkdebug${EXE} -g -debug ${src}${SEP}linkdebug.d ${libname}

rm ${libname}
rm ${dir}/{linkdebug${OBJ},linkdebug${EXE}}
