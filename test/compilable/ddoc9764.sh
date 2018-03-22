#!/usr/bin/env bash

output_html=${RESULTS_DIR}/${TEST_DIR}/${TEST_NAME}.html

rm -f ${output_html}

$DMD -m${MODEL} -D -o- compilable/extra-files/ddoc9764.dd -Df${output_html}

compilable/extra-files/ddocAny-postscript.sh 9764
