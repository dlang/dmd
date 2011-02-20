#!/usr/bin/env bash

dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test2.sh.out

rm -f ${output_file}

a[0]=''
a[1]='-debug'
a[2]='-debug=1'
a[3]='-debug=2 -debug=bar'

for x in "${a[@]}"; do
    echo "executing with args: $x" >> ${output_file}

    $DMD -m${MODEL} $x -unittest -od${dmddir} -of${dmddir}${SEP}test2 runnable/extra-files/test2.d >> ${output_file}
    if [ $? -ne 0 ]; then
        cat ${output_file}
        rm -f ${output_file}
        exit 1
    fi

    ./${dir}/test2 >> ${output_file}
    if [ $? -ne 0 ]; then
        cat ${output_file}
        rm -f ${output_file}
        exit 1
    fi

    rm ${dir}/{test2${OBJ},test2${EXE}}

    echo >> ${output_file}
done
