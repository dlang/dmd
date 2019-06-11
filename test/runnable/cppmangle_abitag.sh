#!/usr/bin/env bash

# Posix only
if [[ "$OS" == "win"* ]]; then
    exit 0
fi

DVER0=_
DVER1=_

$CC --version

if $CC --version | grep -Ei "clang|llvm"; then
    dotver=$($CC --version | grep -Eio -m1 "[0-9.]+" | head -1)
    IFS='.' read -r -a version <<< "$dotver"
    if $CC --version | grep -Ei "apple"; then
        # apple clang versionning is different from open source clang
        # 8.0 matches clang 3.9 https://en.wikipedia.org/wiki/Xcode#Latest_versions
        if [ "${version[0]:-0}" -lt 8 ]; then
            env
            echo Minimum Clang version 3.9 or Apple LLVM 8.0 required
            exit 0
        fi
    else
        if [ "${version[0]:-0}" -lt 3 ] || \
           ([ "${version[0]:-0}" -eq 3 ] && [ "${version[1]:-0}" -lt 9 ]); then
            env
            echo Minimum Clang version 3.9 required
            exit 0
        fi
    fi
    DVER0=clang
else
    IFS='.' read -r -a version <<< "$($CC -dumpversion)"
    if [ "${version[0]:-0}" -lt 5 ]; then
        env
        echo Minimum GCC version 5.0 required
        exit 0
    fi
    if [ "${version[0]:-0}" -ge 6 ]; then
        DVER0=gcc6
    fi
    if [ "${version[0]:-0}" -ge 7 ]; then
        DVER1=gcc7
    fi
fi

env

$CC -std=c++11 -m${MODEL} -I${EXTRA_FILES} -o${OUTPUT_BASE}.cpp${OBJ} -c ${EXTRA_FILES}${SEP}${TEST_NAME}.cpp
$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} -version=${DVER0} -version=${DVER1} -L-lstdc++ ${OUTPUT_BASE}.cpp${OBJ} ${EXTRA_FILES}${SEP}${TEST_NAME}.d

${OUTPUT_BASE}${EXE}

rm_retry ${OUTPUT_BASE}.cpp${OBJ}
rm_retry ${OUTPUT_BASE}${EXE}
