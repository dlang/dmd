#!/usr/bin/env bash


libname=${OUTPUT_BASE}${LIBEXT}


$DMD -m${MODEL} -I${EXTRA_FILES} -of${libname} -lib ${EXTRA_FILES}${SEP}linkdebug_uni.d ${EXTRA_FILES}${SEP}linkdebug_range.d ${EXTRA_FILES}${SEP}linkdebug_primitives.d

$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} -g -debug ${EXTRA_FILES}${SEP}linkdebug.d ${libname}

rm ${OUTPUT_BASE}{${OBJ},${LIBEXT},${EXE}}