#!/usr/bin/env bash

diff --strip-trailing-cr runnable/extra-files/statictor.d.out ${RESULTS_DIR}/runnable/statictor.d.out
if [ $? -ne 0 ]; then
    exit 1;
fi
