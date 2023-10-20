#!/usr/bin/env bash

$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${LIBEXT} -lib ${EXTRA_FILES}/lib21723a.d ${EXTRA_FILES}/lib21723b.d
$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} -inline ${EXTRA_FILES}/test21723.d ${OUTPUT_BASE}${LIBEXT}

rm_retry ${OUTPUT_BASE}{${LIBEXT},${EXE}}
