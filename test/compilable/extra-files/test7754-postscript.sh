#!/usr/bin/env bash

grep -v "D import file generated from" ${OUTPUT_BASE}.di > ${OUTPUT_BASE}.di.2
diff --strip-trailing-cr ${EXTRA_FILES}/${TEST_NAME}.di ${OUTPUT_BASE}.di.2

rm ${OUTPUT_BASE}.di{,.2}
