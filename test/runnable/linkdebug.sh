#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/linkdebug.sh.out

if [ $OS == "win32" -o  $OS == "win64" ]; then
	LIBEXT=.lib
else
	LIBEXT=.a
fi
libname=${dir}${SEP}libX${LIBEXT}

$DMD -m${MODEL} -I${src} -of${libname} -lib ${src}${SEP}linkdebug_uni.d ${src}${SEP}linkdebug_range.d ${src}${SEP}linkdebug_primitives.d || exit 1

$DMD -m${MODEL} -I${src} -of${dir}${SEP}linkdebug${EXE} -g -debug ${src}${SEP}linkdebug.d ${libname} || exit 1

rm ${libname}
rm ${dir}/{linkdebug${OBJ},linkdebug${EXE}}

echo Success > ${output_file}
