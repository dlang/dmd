#!/usr/bin/env bash

if [ $OS == "linux" ] ; then
	gcc -E ${EXTRA_FILES}/importc_test.c >${EXTRA_FILES}/importc_test.i
else
	# TODO Find some prepro for MAC and Windows
	echo "TODO: Add a Windows and Mac C preprocessor!"
	cp ${EXTRA_FILES}/importc_test.i.in ${EXTRA_FILES}/importc_test.i
fi

$DMD -m${MODEL} -I${OUTPUT_BASE} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}${SEP}importc_main.d ${EXTRA_FILES}/importc_test.i

${OUTPUT_BASE}${EXE}

rm_retry ${OUTPUT_BASE}{a${OBJ},${EXE}}
