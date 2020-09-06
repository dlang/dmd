#!/usr/bin/env bash



$DMD -m${MODEL} -I${TEST_DIR} -od${RESULTS_TEST_DIR} -lib ${EXTRA_FILES}/m2.d
$DMD -m${MODEL} -I${TEST_DIR} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}/m1.d ${RESULTS_TEST_DIR}/m2${LIBEXT}


${OUTPUT_BASE}${EXE}

rm_retry ${OUTPUT_BASE}{${OBJ},${EXE}}

