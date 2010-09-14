#!/bin/bash

# trim off the last line which contains the path of the file which differs between windows and non-windows
head -n-1 ${RESULTS_DIR}/runnable/runnable-a20.lst > ${RESULTS_DIR}/runnable/runnable-a20.lst2

diff --strip-trailing-cr runnable/extra-files/runnable-a20.lst ${RESULTS_DIR}/runnable/runnable-a20.lst2
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/runnable/runnable-a20.lst{,2}
rm ${RESULTS_DIR}/runnable/runnable-imports-a20a.lst

