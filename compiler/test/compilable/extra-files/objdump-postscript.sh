#!/usr/bin/env bash

source tools/common_funcs.sh

expect_file=${EXTRA_FILES}/${TEST_NAME}.out
# We are only used by cdcmp, which is a D test,
#  otherwise we could use ${OUTPUT_BASE} and then figure out language.
obj_file=${RESULTS_TEST_DIR}/d/${TEST_NAME}_0.o

echo Creating objdump
objdump --disassemble --disassembler-options=intel "${obj_file}" > "${obj_file}.dump"

echo SANITIZING Objdump...
< "${obj_file}.dump" \
    tail -n+3 | sed 's/[ \t]\s*$//' > "${obj_file}.dump.sanitized"

diff -up --strip-trailing-cr "${expect_file}" "${obj_file}.dump.sanitized"

rm_retry ${obj_file}{,.dump,.dump,.sanitized}
