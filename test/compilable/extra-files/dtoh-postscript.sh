#!/usr/bin/env bash

diff -pu --strip-trailing-cr ${EXTRA_FILES}/${TEST_NAME}.h ${OUTPUT_BASE}.h

rm -f ${OUTPUT_BASE}.h
