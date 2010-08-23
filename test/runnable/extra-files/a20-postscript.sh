#!/bin/bash

diff runnable/extra-files/runnable-a20.lst ${RESULTS_DIR}/runnable/runnable-a20.lst
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/runnable/runnable-a20.lst
rm ${RESULTS_DIR}/runnable/runnable-imports-a20a.lst

