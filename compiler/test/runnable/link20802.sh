#!/usr/bin/env bash


dir=${RESULTS_DIR}${SEP}runnable

libname=${OUTPUT_BASE}${LIBEXT}
exename=${OUTPUT_BASE}${EXE}

$DMD -m${MODEL} -I${EXTRA_FILES} -lib -release -of${libname} ${EXTRA_FILES}${SEP}link20802b.d
$DMD -m${MODEL} -I${EXTRA_FILES} -of${exename} ${EXTRA_FILES}${SEP}link20802a.d ${libname}

${exename}

rm_retry ${OUTPUT_BASE}{${LIBEXT},${EXE},${OBJ}}
