#!/usr/bin/env bash


$DMD -c -preview=dip1008 -m${MODEL} -of${OUTPUT_BASE}${OBJ} -I${EXTRA_FILES} ${EXTRA_FILES}/${TEST_NAME}.d
!(nm ${OUTPUT_BASE}${OBJ} | grep _d_newclass)

rm_retry ${OUTPUT_BASE}${OBJ}
