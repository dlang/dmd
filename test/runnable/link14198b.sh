#!/usr/bin/env bash

out_file=${OUTPUT_BASE}.out

rm -f ${out_file}

# Do not link failure even without library file.

$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE}                   ${EXTRA_FILES}${SEP}test14198.d > ${out_file} 2>&1
grep -q "_D8std141984conv11__T2toTAyaZ9__T2toTbZ2toFNaNbNiNfbZAya" ${out_file} && exit 1

$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} -version=bug14198 ${EXTRA_FILES}${SEP}test14198.d > ${out_file} 2>&1
grep -q "_D8std141984conv11__T2toTAyaZ9__T2toTbZ2toFNaNbNiNfbZAya" ${out_file} && exit 1

rm ${OUTPUT_BASE}{${OBJ},${EXE}}
