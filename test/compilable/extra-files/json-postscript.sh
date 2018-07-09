#!/usr/bin/env bash

echo SANITIZING JSON...
${RESULTS_DIR}/sanitize_json ${OUTPUT_BASE}.out > ${OUTPUT_BASE}.out.sanitized

diff -pu --strip-trailing-cr ${EXTRA_FILES}/${TEST_NAME}.out ${OUTPUT_BASE}.out.sanitized

rm -f ${OUTPUT_BASE}.out{,.sanitized}
