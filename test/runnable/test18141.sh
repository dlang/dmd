#!/usr/bin/env bash

if [ "${OS}" == "windows" ]; then
    expected="Windows"
else
    expected="Posix"
fi

out=$(echo "void main(){}" | "${DMD}" -v -o- -)
echo "$out" | grep "predefs" | grep "${expected}"
