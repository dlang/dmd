#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test10386.sh.out

if [ $OS == "win32" -o  $OS == "win64" ]; then
	LIBEXT=.lib
else
	LIBEXT=.a
fi
libname=${dir}${SEP}lib10386${LIBEXT}

$DMD -m${MODEL} -Irunnable -I${src} -of${libname} -c ${src}${SEP}lib10386${SEP}foo${SEP}bar.d ${src}${SEP}lib10386${SEP}foo${SEP}package.d -lib || exit 1
$DMD -m${MODEL} -Irunnable -I${src} -of${dir}${SEP}test10386${EXE} ${src}${SEP}test10386.d ${libname} || exit 1

rm ${dir}/{lib10386${LIBEXT},test10386${OBJ},test10386${EXE}}

echo Success >${output_file}
