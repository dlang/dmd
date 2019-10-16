#!/usr/bin/env bash

# trim off the first line which contains the path of the file which differs between windows and non-windows
# also trim off compiler debug message and remove CR
grep -v "runnable\|DEBUG\|DMD" $1 | tr -d "\r" > ${OUTPUT_BASE}.d.out.2

diff -pu --strip-trailing-cr ${EXTRA_FILES}/${TEST_NAME}.d.out ${OUTPUT_BASE}.d.out.2

rm ${OUTPUT_BASE}.d.out.2
