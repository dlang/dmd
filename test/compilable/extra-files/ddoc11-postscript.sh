#!/bin/bash

diff compilable/extra-files/ddoc11.html ${RESULTS_DIR}/compilable/ddoc11.html
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/ddoc11.html

