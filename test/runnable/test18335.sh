#!/usr/bin/env bash

set -ueo pipefail

if [ "${OS}" == "osx" ] && [ "${MODEL}" == "64" ]; then
    echo "void main(){}" | "${DMD}" -o- -v - | grep predefs | grep -q "D_ObjectiveC"
fi
