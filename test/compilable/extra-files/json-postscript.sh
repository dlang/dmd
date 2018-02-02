#!/usr/bin/env bash

echo SANITIZING JSON...
${RESULTS_DIR}/sanitize_json ${RESULTS_DIR}/compilable/json.out > ${RESULTS_DIR}/compilable/json.out.sanitized
if [ $? -ne 0 ]; then
    exit 1;
fi

diff --strip-trailing-cr compilable/extra-files/json.out ${RESULTS_DIR}/compilable/json.out.sanitized
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/json.out.sanitized
