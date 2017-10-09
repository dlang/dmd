#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test17619.sh.out

if [ ${OS} != "linux" ]; then
    echo "Skipping test17619 on ${OS}."
    touch ${output_file}
    exit 0
fi 

$DMD -m${MODEL} -I${src} -of${dir}${SEP}test17619${OBJ} -c ${src}${SEP}test17619.d || exit 1
# error out if there is an advance by 0 for a non.zero address
objdump -Wl ${RESULTS_DIR}/runnable/test17619${OBJ} | grep "advance Address by 0 to 0x[1-9]" && exit 1

rm ${dir}/test17619${OBJ}

echo Success >${output_file}
