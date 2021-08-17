#!/usr/bin/env bash

source tools/common_funcs.sh

# strip out Dmain since it's symbol differs between windows and non-windows
grep -v Dmain ${OUTPUT_BASE}.d.trace.def > ${OUTPUT_BASE}.d.trace.def2

diff -up --strip-trailing-cr ${EXTRA_FILES}/${TEST_NAME}.d.trace.def ${OUTPUT_BASE}.d.trace.def2

tracelog=${OUTPUT_BASE}.d.trace.log
if [ ! -f ${tracelog} ]; then
    echo "missing file: ${tracelog}"
    exit 1
fi

rm_retry ${OUTPUT_BASE}.d.trace.{def,def2,log}
