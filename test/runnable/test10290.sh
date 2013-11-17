#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test10290.sh.out

$DMD -m${MODEL} -I${src} -of${dir}${SEP}test10290 ${src}${SEP}test10290.d || exit 1

if [ -f ${RESULTS_DIR}/runnable/test10290 ] ; then
	exit 1	
fi
if [ ! -f ${RESULTS_DIR}/runnable/test10290${EXE} ] ; then
	exit 1	
fi
$DMD -m${MODEL} -I${src} -of${dir}${SEP}test10290${EXE} ${src}${SEP}test10290.d || exit 1
if [ ! -f ${RESULTS_DIR}/runnable/test10290${EXE} ] ; then
	exit 1	
fi
$DMD -m${MODEL} -I${src} -of${dir}${SEP}test10290.abc ${src}${SEP}test10290.d || exit 1
if [ ! -f ${RESULTS_DIR}/runnable/test10290.abc ] ; then
	exit 1	
fi

rm ${dir}/{test10290.$(OBJ},test10290${EXE},test10290.abc}

echo Success >${output_file}
