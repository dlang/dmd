#!/usr/bin/env bash

set -e

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/link846.sh.out

if [ $OS == "win32" -o  $OS == "win64" ]; then
	LIBEXT=.lib
else
	LIBEXT=.a
fi
libname=${dir}${SEP}link846${LIBEXT}

# build library with -release
$DMD -m${MODEL} -I${src} -of${libname} -release -boundscheck=off -lib ${src}${SEP}lib846.d

# use lib with -debug
$DMD -m${MODEL} -I${src} -of${dir}${SEP}link846${EXE} -debug ${src}${SEP}main846.d ${libname}

rm ${libname}
rm ${dir}/{link846${OBJ},link846${EXE}}

echo Success > ${output_file}
