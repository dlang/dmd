#!/usr/bin/env bash

TEST_NAME=$1

echo SANITIZING JSON...
${RESULTS_DIR}/sanitize_json ${RESULTS_DIR}/compilable/${TEST_NAME}.out > ${RESULTS_DIR}/compilable/${TEST_NAME}.out.sanitized

diff -p --strip-trailing-cr compilable/extra-files/${TEST_NAME}.out ${RESULTS_DIR}/compilable/${TEST_NAME}.out.sanitized

rm -f ${RESULTS_DIR}/compilable/${TEST_NAME}.out
rm -f ${RESULTS_DIR}/compilable/${TEST_NAME}.out.sanitized
