#!/usr/bin/env bash

source tools/common_funcs.sh

grep -v "D import file generated from" ${OUTPUT_BASE}.di > ${OUTPUT_BASE}.di.2
test_name=${TEST_NAME/test/}
diff -up --strip-trailing-cr ${EXTRA_FILES}/${test_name}.di ${OUTPUT_BASE}.di.2

rm_retry ${OUTPUT_BASE}.di{,.2}
