#!/usr/bin/env bash

# trim off the last line which contains the path of the file which differs between windows and non-windows
out_file=${RESULTS_TEST_DIR}/${TEST_DIR}-${TEST_NAME}.lst
LINE_COUNT_MINUS_1=$(( `wc -l < ${out_file}` - 1 ))
head -n${LINE_COUNT_MINUS_1} ${out_file} > ${out_file}2

diff --strip-trailing-cr ${EXTRA_FILES}/${TEST_DIR}-${TEST_NAME}.lst ${out_file}2

rm ${out_file}{,2}
