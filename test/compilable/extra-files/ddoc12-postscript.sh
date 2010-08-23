#!/bin/bash

diff compilable/extra-files/ddoc12.html ${RESULTS_DIR}/compilable/ddoc12.html
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/ddoc12.html

