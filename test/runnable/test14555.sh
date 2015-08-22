#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test14555.sh.out

if [ $OS == "win32" -o  $OS == "win64" ]; then
	LIBEXT=.lib
else
	LIBEXT=.a
fi
libname=${dir}${SEP}lib14555${LIBEXT}

$DMD -m${MODEL} -I${src} -of${libname} -lib ${src}${SEP}lib14555.d || exit 1
$DMD -m${MODEL} -I${src} -of${dir}${SEP}test14555${EXE} ${src}${SEP}test14555.d ${libname} || exit 1
./${dir}${SEP}test14555${EXE} || exit 1

rm ${dir}/{lib14555${LIBEXT},test14555${OBJ},test14555${EXE}}

echo Success >${output_file}
