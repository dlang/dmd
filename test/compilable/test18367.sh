#!/usr/bin/env bash


# dmd should not segfault on -X with libraries, but no source files
out=$(! "$DMD" -conf= -X foo.a 2>&1)
echo "$out" | grep 'Error: cannot determine JSON filename, use `-Xf=<file>` or provide a source file'

out=$(! "$DMD" -conf= -Xi=compilerInfo 2>&1)
echo "$out" | grep 'Error: cannot determine JSON filename, use `-Xf=<file>` or provide a source file'
