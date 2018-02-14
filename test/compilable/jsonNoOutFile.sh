#!/usr/bin/env bash
set -euo pipefail
dir=${RESULTS_DIR}/compilable
output_file=${dir}/jsonNoOutFile.sh.out
$DMD -c -od=${dir} -Xi=compilerInfo compilable/extra-files/emptymain.d > ${output_file}
rm -f emptymain.json || true

