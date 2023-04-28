#!/usr/bin/env bash

source tools/common_funcs.sh

# strip out Dmain since it's symbol differs between windows and non-windows
# strip out _d_arraycatnTX and _d_arraysetlengthT since they are part of the
# lowering of the array concatenation operator
grep -v 'Dmain\|_d_arraycatnTX\|_d_arraysetlengthT' ${OUTPUT_BASE}.d.trace.def > ${OUTPUT_BASE}.d.trace.def2

diff -up --strip-trailing-cr ${EXTRA_FILES}/${TEST_NAME}.d.trace.def ${OUTPUT_BASE}.d.trace.def2

tracelog=${OUTPUT_BASE}.d.trace.log
if [ ! -f ${tracelog} ]; then
    echo "missing file: ${tracelog}"
    exit 1
fi

rm_retry ${OUTPUT_BASE}.d.trace.{def,def2,log}
