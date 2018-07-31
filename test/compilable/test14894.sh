#!/usr/bin/env bash


$DMD -c -m${MODEL} -of${OUTPUT_BASE}a${OBJ} -I${EXTRA_FILES} ${EXTRA_FILES}/${TEST_NAME}a.d


$DMD -unittest -m${MODEL} -od${RESULTS_TEST_DIR} -I${EXTRA_FILES} ${EXTRA_FILES}/${TEST_NAME}main.d ${OUTPUT_BASE}a${OBJ}

rm -f ${OUTPUT_BASE}a${OBJ} ${TEST_NAME}main${EXE} ${TEST_NAME}main${OBJ}}
