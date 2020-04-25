#!/usr/bin/env bash

errmsg="$(! $DMD -c -o- -main -m32 -m64 ${EXTRA_FILES}/minimal/object.d 2>&1 > /dev/null)"
expected="Error: Conflicting target architectures specified: -m32 and -m64."

if [ "$errmsg" != "$expected" ]; then exit 1; fi

exit 0
