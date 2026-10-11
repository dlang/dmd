#!/usr/bin/env bash

source tools/common_funcs.sh

TMP_FILE=${RESULTS_DIR}/compilable/${TEST_NAME}

# Find all AA instantiations, error on any unexpected arguments
grep "\<Impl!" "${TEST_DIR}/${TEST_NAME}.d.cg" > "${TMP_FILE}.impl"
! grep -v "Impl!(int, E)" "${TMP_FILE}.impl" >"${TMP_FILE}.bad"

ret=$?

rm_retry "${TEST_DIR}/${TEST_NAME}.d.cg"

exit $ret
