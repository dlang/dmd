#!/bin/bash

diff compilable/extra-files/xheader.di ${RESULTS_DIR}/compilable/xheader.di
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/xheader.di
