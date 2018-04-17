#!/usr/bin/env bash
$DMD -c -od=${RESULTS_TEST_DIR} -Xi=compilerInfo ${EXTRA_FILES}/emptymain.d
rm -f emptymain.json
