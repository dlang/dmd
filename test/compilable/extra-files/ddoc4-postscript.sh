#!/bin/bash

diff compilable/extra-files/ddoc4.html ${RESULTS_DIR}/compilable/ddoc4.html
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/ddoc4.html

