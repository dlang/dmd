#!/usr/bin/env bash

grep -v "D import file generated from" ${OUTPUT_BASE}.di > ${OUTPUT_BASE}.di.2
test_name=${TEST_NAME/test/}
diff -p --strip-trailing-cr ${EXTRA_FILES}/${test_name}.di ${OUTPUT_BASE}.di.2

rm ${OUTPUT_BASE}.di{,.2}
