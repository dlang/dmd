#!/usr/bin/env bash

libname=${OUTPUT_BASE}${LIBEXT}

$DMD -m${MODEL} -I${EXTRA_FILES} -of${libname} -c ${EXTRA_FILES}${SEP}mul9377a.d ${EXTRA_FILES}${SEP}mul9377b.d -lib || exit 1
$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}${SEP}multi9377.d ${libname} || exit 1
rm ${OUTPUT_BASE}{${LIBEXT},${OBJ},${EXE}}
