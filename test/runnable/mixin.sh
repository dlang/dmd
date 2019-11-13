#!/usr/bin/env bash

src_file=${EXTRA_FILES}/${TEST_NAME}.d
expect_file=${EXTRA_FILES}/${TEST_NAME}.mixin
tmp_file=${RESULTS_TEST_DIR}/${TEST_NAME}.mixin

$DMD -o- -mixin=${tmp_file} -g ${src_file}
tr '\\' '/' < ${tmp_file} > ${tmp_file}2
diff -pu --strip-trailing-cr ${expect_file} ${tmp_file}2

rm ${tmp_file} ${tmp_file}2
