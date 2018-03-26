#!/usr/bin/env bash

output_file=${OUTPUT_BASE}.log

echo 'import std.stdio; void main() { writeln("Success"); }' | \
	$DMD -m${MODEL} -run - > ${output_file} || exit 1
grep -q '^Success$' ${output_file} || exit 1
