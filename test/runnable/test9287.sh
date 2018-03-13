#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable

echo 'import std.stdio; void main() { writeln("Success"); }' | \
	$DMD -m${MODEL} -of${dir}${SEP}test9287a${EXE} - || exit 1

${RESULTS_DIR}/runnable/test9287a${EXE}

rm -f ${dir}/test9287a{${OBJ},${EXE}}
