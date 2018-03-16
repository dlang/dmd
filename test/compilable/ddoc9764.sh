#!/usr/bin/env bash

output_file=${RESULTS_DIR}/${TEST_DIR}/${TEST_NAME}.html

rm -f ${output_file}

$DMD -m${MODEL} -D -o- compilable/extra-files/ddoc9764.dd -Df${output_file}

compilable/extra-files/ddocAny-postscript.sh 9764 && touch ${RESULTS_DIR}/${TEST_NAME}.out
