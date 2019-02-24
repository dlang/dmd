#!/usr/bin/env bash
# https://issues.dlang.org/show_bug.cgi?id=7524

output="$(echo '#line 47 __DATE__' | (! "$DMD" -c -o- - 2>&1))"

line1='__stdin.d(1): Error: #line integer ["filespec"]\n expected'
if [ "$(echo "$output" | head -n1 | tr -d "\r")"  != "$line1" ] ; then
    exit 1
fi
if [ "$("$output" | wc -l)"  -eq 2 ] ; then
    exit 1
fi
echo "$output" | tail -n1 | grep "__stdin.d(1): Error: declaration expected, not "
