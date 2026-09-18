#!/usr/bin/env bash

if [[ $OS = "win"* ]] && ! which -s nm; then
    echo 'No `nm` tool found in PATH, skipping test on Windows.'
    exit 0
fi

$DMD -c -preview=dip1008 -m${MODEL} -of${OUTPUT_BASE}${OBJ} -I${EXTRA_FILES} ${EXTRA_FILES}/${TEST_NAME}.d
echo ".: ================================================="
nm ${OUTPUT_BASE}${OBJ}
echo ".: ================================================="
nm ${OUTPUT_BASE}${OBJ} | (! grep _d_newclass)

rm_retry ${OUTPUT_BASE}${OBJ}
