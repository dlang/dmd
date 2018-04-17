#!/usr/bin/env bash

if [ ${OS} != "linux" ]; then
    echo "Skipping test17619 on ${OS}."
    exit 0
fi

$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${OBJ} -c ${EXTRA_FILES}${SEP}test17619.d || exit 1
# error out if there is an advance by 0 for a non.zero address
objdump -Wl ${RESULTS_DIR}/runnable/test17619${OBJ} | grep "advance Address by 0 to 0x[1-9]" && exit 1

rm ${OUTPUT_BASE}${OBJ}
