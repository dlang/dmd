#!/usr/bin/env bash

if [ $OS == "linux" ] ; then
	gcc -E ${EXTRA_FILES}/importc_test.c >${EXTRA_FILES}/importc_test.i
else
	# TODO Find some prepro for MAC and Windows
	echo "TODO: Add a Windows and Mac C preprocessor!"
	cp ${EXTRA_FILES}/importc_test.i.in ${EXTRA_FILES}/importc_test.i
fi

# Case1: The referenced .i is passed on commandline
$DMD -m${MODEL} -I${OUTPUT_BASE} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}${SEP}importc_main.d ${EXTRA_FILES}${SEP}importc_test.i

${OUTPUT_BASE}${EXE}

# Case2: The referenced module compiled from an .i file is NOT passed on commandline
#        and the compiler has to guess the right name.
#        Note: object is passed to keep linker happy
#        Note: if the module object created from the .i file just contains DECLARATIONS, you can omit the ${OBJ} file.
#              There is no code to link in this case. This work e.g. for preprocessed C headers, e.g. /usr/include/zstd.h
$DMD -c -m${MODEL} -I${OUTPUT_BASE} ${EXTRA_FILES}${SEP}importc_test.i -of=${EXTRA_FILES}${SEP}importc_test${OBJ}
$DMD -m${MODEL} -I${OUTPUT_BASE} -of${OUTPUT_BASE}${EXE} -I${EXTRA_FILES} ${EXTRA_FILES}${SEP}importc_test${OBJ} ${EXTRA_FILES}${SEP}importc_main2.d

${OUTPUT_BASE}${EXE}

rm_retry ${OUTPUT_BASE}{a${OBJ},${EXE}} ${EXTRA_FILES}${SEP}importc_test${OBJ} ${EXTRA_FILES}/importc_test.i
