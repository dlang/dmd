#!/usr/bin/env bash

dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test18141.sh.out

set -e

if [ "${OS}" == "win32" -o "${OS}" == "win64" ]; then
    expected="Windows"
else
    expected="Posix"
fi

echo "void main(){}" | "${DMD}" -v -o- - | grep "predefs" | grep "${expected}" > "${output_file}"
