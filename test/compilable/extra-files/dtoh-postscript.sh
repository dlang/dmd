#!/usr/bin/env bash

diff -pu --strip-trailing-cr ${EXTRA_FILES}/${TEST_NAME}.out ${OUTPUT_BASE}.out

rm -f ${OUTPUT_BASE}.out
