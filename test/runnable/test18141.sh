#!/usr/bin/env bash

set -e

if [ "${OS}" == "win32" -o "${OS}" == "win64" ]; then
    expected="Windows"
else
    expected="Posix"
fi

echo "void main(){}" | "${DMD}" -v -o- - | grep "predefs" | grep "${expected}"
