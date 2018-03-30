#!/usr/bin/env bash

# trim off the last line which contains the path of the file which differs between windows and non-windows
LINE_COUNT_MINUS_1=$(( `wc -l < ${RESULTS_DIR}/runnable/runnable-sieve.lst` - 1 ))
head -n${LINE_COUNT_MINUS_1} ${RESULTS_DIR}/runnable/runnable-sieve.lst > ${RESULTS_DIR}/runnable/runnable-sieve.lst2

diff --strip-trailing-cr runnable/extra-files/runnable-sieve.lst ${RESULTS_DIR}/runnable/runnable-sieve.lst2

rm ${RESULTS_DIR}/runnable/runnable-sieve.lst{,2}
