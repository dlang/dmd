#!/usr/bin/env bash

set -e

echo 'import std.stdio; void main() { writeln("Success"); }' | \
	$DMD -m${MODEL} -of${OUTPUT_BASE}${EXE} -

${OUTPUT_BASE}${EXE}

rm_retry -f ${OUTPUT_BASE}{${OBJ},${EXE}}
