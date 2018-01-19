#!/usr/bin/env bash

set -e


if [ "${OS}" == "win32" -o "${OS}" == "win64" ]; then
    expected="windows"
else
    expected="posix"
fi

"${DMD}" -probe | grep "${expected}"
