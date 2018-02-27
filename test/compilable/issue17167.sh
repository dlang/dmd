#!/usr/bin/env bash

set -euo pipefail

# Test that file paths larger than 248 characters can be used
# Test CRLF and mixed line ending handling in D lexer.

dir=${RESULTS_DIR}/compilable/

test_dir=${dir}/${TEST_NAME}/uuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuu
[[ -d $test_dir ]] || mkdir -p "$test_dir"
bin_base=${test_dir}/${TEST_NAME}
bin="$bin_base$OBJ"
src="$bin_base.d"

echo 'void main() {}' > "${src}"

# Only compile, not link, since optlink can't handle long file names
$DMD -m"${MODEL}" "${DFLAGS}" -c -of"${bin}" "${src}" || exit 1

rm -rf "${dir:?}"/"$TEST_NAME"

echo Success
