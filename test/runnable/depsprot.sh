#!/usr/bin/env bash

deps_file="${OUTPUT_BASE}.deps"

# custom error handling
set +eo pipefail

die()
{
    echo "---- deps file ----"
    cat ${deps_file}
    echo
    echo "$@"
    rm -f ${deps_file}
    exit 1
}

$DMD -m${MODEL} -deps=${deps_file} -Irunnable/imports -o- ${EXTRA_FILES}/${TEST_NAME}.d
test $? -ne 0 &&
    die "Error compiling"

grep "^${TEST_NAME}.*${TEST_NAME}_default" ${deps_file} | grep -q private ||
    die "Default import protection in dependency file should be 'private'"

grep "^${TEST_NAME}.*${TEST_NAME}_public" ${deps_file} | grep -q public ||
    die "Public import protection in dependency file should be 'public'"

grep "^${TEST_NAME}.*${TEST_NAME}_private" ${deps_file} | grep -q private||
    die "Private import protection in dependency file should be 'private'"

echo "Dependencies file:"
cat ${deps_file}
echo

rm ${deps_file}
