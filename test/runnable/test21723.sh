#!/usr/bin/env bash


libname=${OUTPUT_BASE}_dep${LIBEXT}


$DMD -m${MODEL} -I${EXTRA_FILES} -of${libname} -lib ${EXTRA_FILES}/lib21723a.d ${EXTRA_FILES}/lib21723b.d
$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} -inline ${EXTRA_FILES}/test21723.d ${libname}

rm_retry ${OUTPUT_BASE}{${LIBEXT},${EXE}}
