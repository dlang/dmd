#!/usr/bin/env bash


$DMD -m${MODEL} -I${EXTRA_FILES} -lib -cov -of${OUTPUT_BASE}${LIBEXT} ${EXTRA_FILES}${SEP}lib13742a.d ${EXTRA_FILES}${SEP}lib13742b.d
$DMD -m${MODEL} -I${EXTRA_FILES} -cov -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}${SEP}test13742.d ${OUTPUT_BASE}${LIBEXT}

${OUTPUT_BASE}${EXE} --DRT-covopt=dstpath:${RESULTS_TEST_DIR}

rm_retry -f ${RESULTS_TEST_DIR}/runnable-extra-files-{lib13742a,lib13742b,test13742}.lst
rm_retry -f ${OUTPUT_BASE}{${OBJ},${LIBEXT},${EXE}}
