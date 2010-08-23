#!/bin/bash

diff compilable/extra-files/header.di ${RESULTS_DIR}/compilable/header.di
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/header.di
