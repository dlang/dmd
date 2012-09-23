#!/usr/bin/env bash

dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable
log_file=${dir}/test2.sh.log

rm -f ${log_file}

a[0]=''
a[1]='-debug'
a[2]='-debug=1'
a[3]='-debug=2 -debug=bar'

for x in "${a[@]}"; do
    echo "executing with args: $x" >> ${log_file}

    $DMD -m${MODEL} $x -unittest -od${dmddir} -of${dmddir}${SEP}test2 runnable/extra-files/test2.d >> ${log_file}
    if [ $? -ne 0 ]; then
        cat ${log_file}
        rm -f ${log_file}
        exit 1
    fi

    ./${dir}/test2 >> ${log_file}
    if [ $? -ne 0 ]; then
        cat ${log_file}
        rm -f ${log_file}
        exit 1
    fi

    rm ${dir}/{test2${OBJ},test2${EXE}}

    echo >> ${log_file}
done
