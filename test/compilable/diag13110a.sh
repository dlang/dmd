#!/usr/bin/env bash

set -euo pipefail

name=`basename $0 .sh`
dir=${RESULTS_DIR}/compilable
output_file=${dir}/${name}.d

out=$(${DMD} -m${MODEL} -run compilable/extra-files/hello.d)
echo ${out} | grep -q hello

out=$(${DMD} -m${MODEL} compilable/extra-files/hello.d -run "")
echo ${out} | grep -q hello
