#!/usr/bin/env bash


# Test that file paths larger than 248 characters can be used
# Test CRLF and mixed line ending handling in D lexer.

test_dir=${OUTPUT_BASE}/uuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuu

mkdir -p "$test_dir"
bin_base=${test_dir}/${TEST_NAME}
bin="$bin_base$OBJ"
src="$bin_base.d"

echo 'void main() {}' > "${src}"

# Only compile, not link, since optlink can't handle long file names
$DMD -m"${MODEL}" "${DFLAGS}" -c -of"${bin}" "${src}"

rm -rf "${OUTPUT_BASE}"
