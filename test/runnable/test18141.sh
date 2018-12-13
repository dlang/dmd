#!/usr/bin/env bash

if [ "${OS}" == "win32" -o "${OS}" == "win64" ]; then
    expected="Windows"
else
    expected="Posix"
fi

out=$(echo "void main(){}" | "${DMD}" -v -o- -)
echo "$out" | grep "predefs" | grep "${expected}"
