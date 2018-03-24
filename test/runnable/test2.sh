#!/usr/bin/env bash


dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable

a[0]=''
a[1]='-debug'
a[2]='-debug=1'
a[3]='-debug=2 -debug=bar'

for x in "${a[@]}"; do
    echo "executing with args: $x"

    $DMD -m${MODEL} $x -unittest -od${dmddir} -of${dmddir}${SEP}test2${EXE} runnable/extra-files/test2.d

    ${dir}/test2

    rm ${dir}/{test2${OBJ},test2${EXE}}

    echo
done
