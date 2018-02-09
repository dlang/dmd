#!/usr/bin/env bash

set -u -o pipefail

name=$(basename "$0" .sh)
dir=${RESULTS_DIR}/compilable/

# dmd should not segfault on -X with libraries, but no source files
out=$("$DMD" -conf= -X foo.a 2>&1)
[ $? -eq 1 ] || exit 1
echo "$out" | grep -q "Error: -X requires source files"
