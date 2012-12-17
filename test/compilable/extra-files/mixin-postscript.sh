#!/usr/bin/env bash

diff --strip-trailing-cr compilable/extra-files/mixin.mixin ${RESULTS_DIR}/compilable/mixin.mixin
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/mixin.mixin

