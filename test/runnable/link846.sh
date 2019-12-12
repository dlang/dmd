#!/usr/bin/env bash


libname=${OUTPUT_BASE}${LIBEXT}

# build library with -release
$DMD -m${MODEL} -I${EXTRA_FILES} -of${libname} -release -boundscheck=off -lib ${EXTRA_FILES}${SEP}lib846.d

# use lib with -debug
$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} -debug ${EXTRA_FILES}${SEP}main846.d ${libname}

rm_retry ${OUTPUT_BASE}{${OBJ},${EXE},${LIBEXT}}
