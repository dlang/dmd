#!/usr/bin/env bash


src=${EXTRA_FILES}/${TEST_NAME}


$DMD -lib -m${MODEL} -of${OUTPUT_BASE}a${LIBEXT} -I${src} ${src}/a.d
$DMD -lib -m${MODEL} -of${OUTPUT_BASE}b${LIBEXT} -I${src} ${src}/b.d

$DMD -m${MODEL} -of${OUTPUT_BASE}_main -I${src} ${src}/main.d ${OUTPUT_BASE}a${LIBEXT} ${OUTPUT_BASE}b${LIBEXT}

rm -f ${OUTPUT_BASE}{a${LIBEXT},b${LIBEXT},_main${EXE},_main${OBJ}}
