#!/bin/bash

# trim off the last line which contains the path of the file which differs between windows and non-windows
head -n-1 ${RESULTS_DIR}/runnable/runnable-sieve.lst > ${RESULTS_DIR}/runnable/runnable-sieve.lst2

diff -w runnable/extra-files/runnable-sieve.lst ${RESULTS_DIR}/runnable/runnable-sieve.lst2
if [ $? -ne 0 ]; then
    exit 1
fi

rm ${RESULTS_DIR}/runnable/runnable-sieve.lst{,2}

