#!/usr/bin/env bash


$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}a${OBJ} -c ${EXTRA_FILES}${SEP}test10567a.d
$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}${SEP}test10567.d ${OUTPUT_BASE}a${OBJ}

${OUTPUT_BASE}${EXE}

rm_retry ${OUTPUT_BASE}{a${OBJ},${EXE}}
