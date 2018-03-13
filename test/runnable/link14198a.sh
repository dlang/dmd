#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/link14198a.sh.out

libname=${dir}${SEP}lib14198a${LIBEXT}

# build library
$DMD -m${MODEL} -I${src} -of${libname} -lib ${src}${SEP}std14198${SEP}array.d ${src}${SEP}std14198${SEP}conv.d ${src}${SEP}std14198${SEP}format.d ${src}${SEP}std14198${SEP}uni.d || exit 1

# Do not link failure with library file, regardless the semantic order.
$DMD -m${MODEL} -I${src} -of${dir}${SEP}test14198a${EXE}                   ${src}${SEP}test14198.d ${libname} || exit 1
$DMD -m${MODEL} -I${src} -of${dir}${SEP}test14198a${EXE} -version=bug14198 ${src}${SEP}test14198.d ${libname} || exit 1

rm ${libname}
rm ${dir}/{test14198a${OBJ},test14198a${EXE}}

echo Success > ${output_file}
