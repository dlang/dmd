#!/usr/bin/env bash


src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable

libname=${dir}${SEP}link846${LIBEXT}

# build library with -release
$DMD -m${MODEL} -I${src} -of${libname} -release -boundscheck=off -lib ${src}${SEP}lib846.d

# use lib with -debug
$DMD -m${MODEL} -I${src} -of${dir}${SEP}link846${EXE} -debug ${src}${SEP}main846.d ${libname}

rm ${libname}
rm ${dir}/{link846${OBJ},link846${EXE}}
