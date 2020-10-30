#!/usr/bin/env bash

source tools/common_funcs.sh

# Test if there's call to the runtime for .length = 100
grep "_d_arraysetlengthT(arr, 100.*)" "${TEST_DIR}/${TEST_NAME}.d.cg"
# Make sure there's no call to the runtime for .length = 0
! grep "_d_arraysetlengthT(arr, 0.*)" "${TEST_DIR}/${TEST_NAME}.d.cg"
# Test if a slice expr is applied for the above case
grep "arr = arr\[0..0\]" "${TEST_DIR}/${TEST_NAME}.d.cg"

rm_retry "${TEST_DIR}/${TEST_NAME}.d.cg"
