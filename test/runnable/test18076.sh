#!/usr/bin/env bash

output_file=${OUTPUT_BASE}.log

echo 'import std.stdio; void main() { writeln("Success"); }' | \
	$DMD -m${MODEL} -run - > ${output_file}
grep -q '^Success$' ${output_file}

rm "${output_file}"
