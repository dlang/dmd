#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable

if [ $OS == "win32" -o  $OS == "win64" ]; then
	LIBEXT=.lib
else
	LIBEXT=.a
fi
libname=${dir}${SEP}lib9377${LIBEXT}

$DMD -m${MODEL} -I${src} -of${libname} -c ${src}${SEP}mul9377a.d ${src}${SEP}mul9377b.d -lib
$DMD -m${MODEL} -I${src} -of${dir}${SEP}mul9377 ${src}${SEP}multi9377.d ${libname}

rm ${dir}/{lib9377${LIBEXT},mul9377${OBJ},mul9377${EXE}}

