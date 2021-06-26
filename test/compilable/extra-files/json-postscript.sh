#!/usr/bin/env bash

source tools/common_funcs.sh

echo SANITIZING JSON...
${RESULTS_DIR}/sanitize_json ${OUTPUT_BASE}.out > ${OUTPUT_BASE}.out.sanitized

diff -pu --strip-trailing-cr ${EXTRA_FILES}/${TEST_NAME}.json ${OUTPUT_BASE}.out.sanitized

rm_retry ${OUTPUT_BASE}.out{,.sanitized}
