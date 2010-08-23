#!/bin/bash

diff -w compilable/extra-files/ddoc7.html ${RESULTS_DIR}/compilable/ddoc7.html
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/ddoc7.html

