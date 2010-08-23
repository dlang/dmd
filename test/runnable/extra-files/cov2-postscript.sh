#!/bin/bash

diff runnable/extra-files/runnable-cov2.lst ${RESULTS_DIR}/runnable/runnable-cov2.lst
if [ $? -ne 0 ]; then
    exit 1
fi

rm ${RESULTS_DIR}/runnable/runnable-cov2.lst

