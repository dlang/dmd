#!/usr/bin/env bash


dir=${RESULTS_DIR}/runnable

$DMD -m${MODEL} -I${TEST_DIR} -od${RESULTS_TEST_DIR} -of${OUTPUT_BASE}_1${EXE} ${EXTRA_FILES}/test44.d ${TEST_DIR}/imports/test44a.d

${OUTPUT_BASE}_1

$DMD -m${MODEL} -I${TEST_DIR} -od${RESULTS_TEST_DIR} -of${OUTPUT_BASE}_2${EXE} ${TEST_DIR}/imports/test44a.d ${EXTRA_FILES}/test44.d

${OUTPUT_BASE}_2

rm_retry ${OUTPUT_BASE}{_1${OBJ},_1${EXE},_2${OBJ},_2${EXE}}