#!/usr/bin/env bash

# trim off the first line which contains the path of the file which differs between windows and non-windows
# also trim off compiler debug message
grep -v "runnable\|DEBUG" $1 > ${RESULTS_DIR}/runnable/statictor.d.out.2

diff --strip-trailing-cr runnable/extra-files/statictor.d.out ${RESULTS_DIR}/runnable/statictor.d.out.2

rm ${RESULTS_DIR}/runnable/statictor.d.out.2
