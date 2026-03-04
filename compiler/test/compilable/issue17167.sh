#!/usr/bin/env bash


# Test that file paths larger than 248 characters can be used
# Test CRLF and mixed line ending handling in D lexer.

probe_dir=$(dirname "${OUTPUT_BASE}")
name_max=$(getconf NAME_MAX "${probe_dir}" 2>/dev/null || echo 255)
if [ "${name_max}" -lt 249 ]; then
    echo "Skipping ${TEST_NAME}.sh: NAME_MAX=${name_max} < 249, cannot test Windows long-path threshold." >&2
    exit 0
fi

test_dir=${OUTPUT_BASE}/uuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuu

mkdir -p "$test_dir"
bin_base=${test_dir}/${TEST_NAME}
bin="$bin_base$OBJ"
src="$bin_base.d"

echo 'void main() {}' > "${src}"

# Only compile, don't link, since the Microsoft linker doesn't implicitly support long paths
$DMD -m"${MODEL}" "${DFLAGS}" -c -of"${bin}" "${src}"

rm_retry -r "${OUTPUT_BASE}"
