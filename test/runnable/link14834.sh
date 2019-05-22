#!/usr/bin/env bash


dir=${RESULTS_DIR}${SEP}runnable

libname=${OUTPUT_BASE}${LIBEXT}
exename=${OUTPUT_BASE}${EXE}

$DMD -m${MODEL} -I${EXTRA_FILES} -lib           -of${libname} ${EXTRA_FILES}${SEP}link14834a.d
$DMD -m${MODEL} -I${EXTRA_FILES} -inline -debug -of${exename} ${EXTRA_FILES}${SEP}link14834b.d ${libname}

${exename}

rm_retry ${OUTPUT_BASE}{${LIBEXT},${EXE},${OBJ}}
