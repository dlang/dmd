#!/usr/bin/env bash


libname=${OUTPUT_BASE}${LIBEXT}


$DMD -m${MODEL} -Irunnable -I${EXTRA_FILES} -of${libname} -c ${EXTRA_FILES}${SEP}lib10386${SEP}foo${SEP}bar.d ${EXTRA_FILES}${SEP}lib10386${SEP}foo${SEP}package.d -lib
$DMD -m${MODEL} -Irunnable -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}${SEP}test10386.d ${libname}
rm_retry ${OUTPUT_BASE}{${LIBEXT},${OBJ},${EXE}}
