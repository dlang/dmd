#!/bin/bash

diff -w compilable/extra-files/ddoc9.html ${RESULTS_DIR}/compilable/ddoc9.html
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/ddoc9.html

