#!/usr/bin/env bash


libname=${OUTPUT_BASE}_dep${LIBEXT}


$DMD -m${MODEL} -I${EXTRA_FILES} -of${libname} -lib ${EXTRA_FILES}/lib23148.d
$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}/test23148.d ${libname}

rm_retry ${OUTPUT_BASE}{${LIBEXT},${EXE}}
