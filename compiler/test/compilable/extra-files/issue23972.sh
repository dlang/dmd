#!/usr/bin/env bash

source tools/common_funcs.sh

# Find all AA instantiations, error on any unexpected arguments
grep "\<Impl!" "${TEST_DIR}/${TEST_NAME}.d.cg" > "${TEST_DIR}/${TEST_NAME}.d.impl"
! grep -v "Impl!(int, E)" "${TEST_DIR}/${TEST_NAME}.d.impl" >"${TEST_DIR}/${TEST_NAME}.d.bad"

ret=$?

rm_retry "${TEST_DIR}/${TEST_NAME}.d.cg"
rm_retry "${TEST_DIR}/${TEST_NAME}.d.impl"
rm_retry "${TEST_DIR}/${TEST_NAME}.d.bad"

exit $ret
