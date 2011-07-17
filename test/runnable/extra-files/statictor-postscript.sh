#!/usr/bin/env bash

# trim off the first line which contains the path of the file which differs between windows and non-windows
grep -v runnable ${RESULTS_DIR}/runnable/statictor.d.out > ${RESULTS_DIR}/runnable/statictor.d.out.2

diff --strip-trailing-cr runnable/extra-files/statictor.d.out ${RESULTS_DIR}/runnable/statictor.d.out.2
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/runnable/statictor.d.out.2

