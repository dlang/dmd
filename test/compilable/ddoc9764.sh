#!/usr/bin/env bash

name=`basename $0 .sh`
dir=${RESULTS_DIR}/compilable
output_file=${dir}/${name}.html

rm -f ${output_file}

$DMD -m${MODEL} -D -o- compilable/extra-files/ddoc9764.dd -Df${output_file}

compilable/extra-files/ddocAny-postscript.sh 9764 && touch ${dir}/`basename $0`.out
