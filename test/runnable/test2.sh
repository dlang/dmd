#!/usr/bin/env bash


output_file=${OUTPUT_BASE}.log


set -x

a[0]=''
a[1]='-debug'
a[2]='-debug=1'
a[3]='-debug=2 -debug=bar'

for x in "${a[@]}"; do
    echo "executing with args: $x"

    $DMD -m${MODEL} $x -unittest -of${OUTPUT_BASE}${EXE} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}/test2.d >> ${output_file}
    if [ $? -ne 0 ]; then
        cat ${output_file}
        rm -f ${output_file}
        exit 1
    fi

    ${OUTPUT_BASE}${EXE} >> ${output_file}

    rm ${OUTPUT_BASE}{${OBJ},${EXE}}

    echo
done
