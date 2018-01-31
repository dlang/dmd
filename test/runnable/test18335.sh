#!/usr/bin/env bash

output_file="${RESULTS_DIR}/runnable/$(basename $0 .sh)"
set -ueo pipefail

if [ "${OS}" == "osx" ] && [ "${MODEL}" == "64" ]; then
    echo "void main(){}" | "${DMD}" -o- -v - | grep predefs | grep -q "D_ObjectiveC"
fi

echo Success > "${output_file}"
