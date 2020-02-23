#!/usr/bin/env bash

! $DMD -c ${EXTRA_FILES}/fail6592.d -H -Hf${RESULTS_DIR}/fail_compilation/fail6592.di 2> /dev/null

if [ -f ${RESULTS_DIR}/fail_compilation/fail6592.di ]; then exit 1; fi

exit 0
