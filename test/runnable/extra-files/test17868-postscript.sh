#!/usr/bin/env bash

# trim off the first line which contains the path of the file which differs between windows and non-windows
# also trim off compiler debug message
grep -v 'runnable\|DEBUG' $2 > $1

diff --strip-trailing-cr runnable/extra-files/test17868.d.out $1
if [ $? -ne 0 ]; then
    exit 1;
fi

rm -f $1
