#!/usr/bin/env bash


$DMD -c -dip1008 -m${MODEL} -of${OUTPUT_BASE}${OBJ} -I${EXTRA_FILES} ${EXTRA_FILES}/${TEST_NAME}.d
!(nm ${OUTPUT_BASE}${OBJ} | grep _d_newclass)

rm -f ${OUTPUT_BASE}${OBJ}
