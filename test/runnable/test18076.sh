#!/usr/bin/env bash

dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test18076.sh.out

echo 'import std.stdio; void main() { writeln("Success"); }' | \
	$DMD -m${MODEL} -run - > ${output_file} || exit 1
grep -q '^Success$' ${output_file} || exit 1
