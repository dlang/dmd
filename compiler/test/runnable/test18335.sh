#!/usr/bin/env bash


if [ "${OS}" == "osx" ] && [ "${MODEL}" == "64" ]; then
    echo "void main(){}" | "${DMD}" -o- -v - | grep predefs | grep -q "D_ObjectiveC"
fi
