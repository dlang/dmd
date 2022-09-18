#!/usr/bin/env bash

source tools/common_funcs.sh

# Test if there's call to the runtime for .length = 100
grep "_d_arraysetlengthT(arr, 100.*)" "${TEST_DIR}/${TEST_NAME}.d.cg" &&
# Make sure there's no call to the runtime for .length = 0
! grep "_d_arraysetlengthT(\(arr\|f\), 0.*)" "${TEST_DIR}/${TEST_NAME}.d.cg" &&
# Make sure there's no call to the runtime for .length = x
! grep "_d_arraysetlengthT(f, x.*)" "${TEST_DIR}/${TEST_NAME}.d.cg" &&
# Test if a slice expr is applied for the above case
grep "arr = arr\[0..0\]" "${TEST_DIR}/${TEST_NAME}.d.cg"

ret=$?

rm_retry "${TEST_DIR}/${TEST_NAME}.d.cg"

exit $ret
