#!/usr/bin/env bash

if [ "$OS" != 'osx' ] || [ "$MODEL" != '64' ]; then
    echo Success >${output_file}
    exit 0
fi

set -e

src=runnable/extra-files
dir=${RESULTS_DIR}/runnable
output_file=${dir}/test16096.sh.out

$DMD -I${src} -of${dir}${SEP}test16096a.a -lib ${src}/test16096a.d
$DMD -I${src} -of${dir}${SEP}test16096 ${src}/test16096.d ${dir}/test16096a.a -L-framework -LFoundation
${RESULTS_DIR}/runnable/test16096

rm ${dir}/{test16096a.a,test16096}

echo Success >${output_file}
