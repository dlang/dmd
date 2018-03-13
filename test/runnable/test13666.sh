#!/usr/bin/env bash

set -e

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable

libname=${dir}${SEP}lib13666${LIBEXT}

$DMD -m${MODEL} -I${src} -of${libname} -lib ${src}${SEP}lib13666.d
$DMD -m${MODEL} -I${src} -of${dir}${SEP}test13666${EXE} ${src}${SEP}test13666.d ${libname}

rm ${dir}/{lib13666${LIBEXT},test13666${OBJ},test13666${EXE}}
