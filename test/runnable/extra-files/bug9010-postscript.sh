#!/usr/bin/env bash

# trim off the last line which contains the path of the file which differs between windows and non-windows
LINE_COUNT_MINUS_1=$(( `wc -l < ${RESULTS_DIR}/runnable/runnable-bug9010.lst` - 1 ))
head -n${LINE_COUNT_MINUS_1} ${RESULTS_DIR}/runnable/runnable-bug9010.lst > ${RESULTS_DIR}/runnable/runnable-bug9010.lst2

diff --strip-trailing-cr runnable/extra-files/runnable-bug9010.lst ${RESULTS_DIR}/runnable/runnable-bug9010.lst2

rm ${RESULTS_DIR}/runnable/runnable-bug9010.lst{,2}
