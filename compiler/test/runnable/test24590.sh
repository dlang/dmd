#!/usr/bin/env bash

# https://issues.dlang.org/show_bug.cgi?id=24590
# Make sure module destructors aren't run if druntime initialization failed,
# e.g., due to a throwing module constructor.

exePath="${OUTPUT_BASE}${EXE}"
outputPath="${OUTPUT_BASE}.out"

$DMD -m${MODEL} "-of$exePath" ${EXTRA_FILES}/test24590.d

ec=0
"$exePath" &> "$outputPath" || ec=$?

if [[ $ec -ne 1 ]]; then
    echo "Unexpected exit code $ec, expected 1" >&2
    exit 1
fi

if ! grep -q "module constructor" "$outputPath"; then
    echo "Module constructor didn't run" >&2
    exit 1
fi

if grep -q "module destructor" "$outputPath"; then
    echo "Module destructor unexpectedly ran" >&2
    exit 1
fi

rm_retry "$exePath" "$outputPath"
