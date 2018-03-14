#!/usr/bin/env bash

output_html=${OUTPUT_BASE}.html

rm -f ${output_html}

$DMD -m${MODEL} -D -o- ${EXTRA_FILES}/ddoc9764.dd -Df${output_html}


${EXTRA_FILES}/ddocAny-postscript.sh 9764
