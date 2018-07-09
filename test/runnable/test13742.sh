#!/usr/bin/env bash


$DMD -m${MODEL} -I${EXTRA_FILES} -lib -cov -of${OUTPUT_BASE}${LIBEXT} ${EXTRA_FILES}${SEP}lib13742a.d ${EXTRA_FILES}${SEP}lib13742b.d
$DMD -m${MODEL} -I${EXTRA_FILES} -cov -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}${SEP}test13742.d ${OUTPUT_BASE}${LIBEXT}

${OUTPUT_BASE}${EXE} --DRT-covopt=dstpath:${RESULTS_TEST_DIR}

# The removal sometimes spuriously fails on the auto-tester with "rm: cannot remove ‘test_results/runnable/test13742.exe’: Device or resource busy"
# This doesn't verify the test, hence -f and || true are used
rm -f ${RESULTS_TEST_DIR}/runnable-extra-files-{lib13742a,lib13742b,test13742}.lst || true
rm -f ${OUTPUT_BASE}{${OBJ},${LIBEXT},${EXE}} || true
