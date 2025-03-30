#!/usr/bin/env bash

# source file order is important
$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${LIBEXT} -lib ${EXTRA_FILES}/lib18456b.d ${EXTRA_FILES}/lib18456.d
$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}/test18456.d ${OUTPUT_BASE}${LIBEXT}
${OUTPUT_BASE}${EXE}

rm_retry ${OUTPUT_BASE}{${LIBEXT},${EXE}}
