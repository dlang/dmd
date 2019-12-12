#!/usr/bin/env bash

set -e

$DMD -m${MODEL} -I${TEST_DIR} -od${RESULTS_TEST_DIR} -c ${EXTRA_FILES}/test18868_a.d

$DMD -m${MODEL} -I${TEST_DIR} -od${RESULTS_TEST_DIR} -c ${EXTRA_FILES}/test18868_b.d

$DMD -m${MODEL} -of${OUTPUT_BASE}${EXE} ${TEST_DIR}/imports/test18868_fls.d ${OUTPUT_BASE}_a${OBJ} ${OUTPUT_BASE}_b${OBJ}

${OUTPUT_BASE}${EXE}

rm_retry ${OUTPUT_BASE}{${OBJ},_a${OBJ},_b${OBJ},${EXE}}
