#!/bin/bash

diff compilable/extra-files/json.out ${RESULTS_DIR}/compilable/json.out
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/json.out

