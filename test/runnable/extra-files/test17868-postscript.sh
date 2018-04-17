#!/usr/bin/env bash

# trim off the first line which contains the path of the file which differs between windows and non-windows
# also trim off compiler debug message
echo ${OUTPUT_BASE}.out.trim
grep -v 'runnable\|DEBUG' $1 > ${OUTPUT_BASE}.out.trim

diff --strip-trailing-cr ${EXTRA_FILES}/test17868.d.out ${OUTPUT_BASE}.out.trim

rm -f ${OUTPUT_BASE}.out.trim
