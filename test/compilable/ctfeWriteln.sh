#!/bin/sh

result_file=${RESULTS_DIR}/compilable/ctfeWriteln.txt
source_file=compilable/extra-files/ctfeWriteln.d
$DMD -m${MODEL} $x -c -o- $source_file 2> $result_file
if [ $? -ne 0 ]; then
    exit 1;
fi
compilable/extra-files/diff-postscript.sh ctfeWriteln.txt

