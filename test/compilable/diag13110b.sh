#!/usr/bin/env bash

set -euo pipefail

name=`basename $0 .sh`
dir=${RESULTS_DIR}/compilable
output_file=${dir}/${name}.sh.out

out=$(${DMD} -m${MODEL} -run compilable/extra-files/echoargs.d a b c)
echo ${out} | grep -q "a b c"

out=$(${DMD} -m${MODEL} compilable/extra-files/echoargs.d -run "" a b c)
echo ${out} | grep -q "a b c"
