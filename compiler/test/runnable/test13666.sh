#!/usr/bin/env bash


libname=${OUTPUT_BASE}${LIBEXT}


$DMD -m${MODEL} -I${EXTRA_FILES} -of${libname} -lib ${EXTRA_FILES}${SEP}lib13666.d
$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}${SEP}test13666.d ${libname}
rm_retry ${OUTPUT_BASE}{${LIBEXT},${OBJ},${EXE}}
