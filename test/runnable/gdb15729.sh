#!/usr/bin/env bash

GDB_SCRIPT="
b lib15729.d:16
r
echo RESULT=
p s.val
"


libname=${OUTPUT_BASE}_dep${LIBEXT}


$DMD -g -m${MODEL} -I${EXTRA_FILES} -of${libname} -lib ${EXTRA_FILES}${SEP}lib15729.d
$DMD -g -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}${SEP}gdb15729.d ${libname}

if [ $OS == "linux" ]; then
    echo "${GDB_SCRIPT}" > ${OUTPUT_BASE}.gdb
    gdb ${OUTPUT_BASE}${EXE} --batch -x ${OUTPUT_BASE}.gdb | grep 'RESULT=.*1234'
fi

rm_retry -f ${OUTPUT_BASE}{,${OBJ},${EXE},${LIBEXT},.gdb}
