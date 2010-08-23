#!/bin/sh

diff -w runnable/extra-files/runnable-sieve.lst ${RESULTS_DIR}/runnable/runnable-sieve.lst
if [ $? -ne 0 ]; then
    exit 1
fi

rm ${RESULTS_DIR}/runnable/runnable-sieve.lst

