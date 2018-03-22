#!/usr/bin/env bash
set -euo pipefail
dir=${RESULTS_DIR}/compilable
$DMD -c -od=${dir} -Xi=compilerInfo compilable/extra-files/emptymain.d
rm -f emptymain.json
