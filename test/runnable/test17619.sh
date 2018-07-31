#!/usr/bin/env bash

if [ ${OS} != "linux" ]; then
    echo "Skipping test17619 on ${OS}."
    exit 0
fi

$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${OBJ} -c ${EXTRA_FILES}${SEP}test17619.d
# error out if there is an advance by 0 for a non.zero address
! objdump -Wl ${OUTPUT_BASE}${OBJ} | grep "advance Address by 0 to 0x[1-9]"

rm ${OUTPUT_BASE}${OBJ}
