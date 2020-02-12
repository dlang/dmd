#!/usr/bin/env bash



$DMD -m${MODEL} -I${TEST_DIR} -od${RESULTS_TEST_DIR} -c ${EXTRA_FILES}/test35.d

$DMD -m${MODEL} -od${RESULTS_TEST_DIR} -c -release ${TEST_DIR}/imports/test35a.d

$DMD -m${MODEL} -of${OUTPUT_BASE}${EXE} ${OUTPUT_BASE}${OBJ} ${OUTPUT_BASE}a${OBJ}

${OUTPUT_BASE}${EXE}

rm_retry ${OUTPUT_BASE}{${OBJ},a${OBJ},${EXE}}
