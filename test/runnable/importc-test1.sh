#!/usr/bin/env bash

gcc -E ${EXTRA_FILES}/importc_test.c >${EXTRA_FILES}/importc_test.i

$DMD -m${MODEL} -I${OUTPUT_BASE} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}${SEP}importc_main.d ${EXTRA_FILES}/importc_test.i

${OUTPUT_BASE}${EXE}

rm_retry ${OUTPUT_BASE}{a${OBJ},${EXE}}
