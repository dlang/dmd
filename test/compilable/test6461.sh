#!/usr/bin/env bash

name=`basename $0 .sh`
dir=${RESULTS_DIR}/compilable
src=compilable/extra-files/test6461

$DMD -lib -od${dir} -I${src} ${src}/a.d || exit 1
$DMD -lib -od${dir} -I${src} ${src}/b.d || exit 1

if [ "${OS}" == "win32" -o "${OS}" == "Windows_NT" ]; then

    $DMD -od${dir} -I${src} ${src}/main.d ${dir}/a.lib ${dir}/b.lib || exit 1
    rm -f ${dir}/a.lib
    rm -f ${dir}/b.lib
    rm -f ${dir}/main.obj
    rm -f ${dir}/main.exe
else
    $DMD -od${dir} -I${src} ${src}/main.d ${dir}/a.a ${dir}/b.a || exit 1

    rm -f ${dir}/a.a
    rm -f ${dir}/b.a
    rm -f ${dir}/main.o
    rm -f ${dir}/main
fi
