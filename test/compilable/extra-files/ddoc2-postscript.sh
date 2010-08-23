#!/bin/bash

diff compilable/extra-files/ddoc2.html ${RESULTS_DIR}/compilable/ddoc2.html
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/ddoc2.html

