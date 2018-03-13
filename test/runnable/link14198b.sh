#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/link14198b.sh.out

rm -f ${output_file}

libname=${dir}${SEP}lib14198b${LIBEXT}

# Do not link failure even without library file.

$DMD -m${MODEL} -I${src} -of${dir}${SEP}test14198b${EXE}                   ${src}${SEP}test14198.d > ${output_file} 2>&1
grep -q "_D8std141984conv11__T2toTAyaZ9__T2toTbZ2toFNaNbNiNfbZAya" ${output_file} && exit 1

$DMD -m${MODEL} -I${src} -of${dir}${SEP}test14198b${EXE} -version=bug14198 ${src}${SEP}test14198.d > ${output_file} 2>&1
grep -q "_D8std141984conv11__T2toTAyaZ9__T2toTbZ2toFNaNbNiNfbZAya" ${output_file} && exit 1

rm ${dir}/{test14198b${OBJ},test14198b${EXE}}

echo Success > ${output_file}
