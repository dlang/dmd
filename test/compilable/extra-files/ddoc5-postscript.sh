#!/bin/bash

diff -w compilable/extra-files/ddoc5.html ${RESULTS_DIR}/compilable/ddoc5.html
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/ddoc5.html

