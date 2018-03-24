#!/usr/bin/env bash


src=runnable/extra-files
dir=${RESULTS_DIR}/runnable

if [ "$OS" != 'osx' ] || [ "$MODEL" != '64' ]; then
    exit 0
fi

$DMD -I${src} -of${dir}${SEP}test16096a.a -lib ${src}/test16096a.d
$DMD -I${src} -of${dir}${SEP}test16096 ${src}/test16096.d ${dir}/test16096a.a -L-framework -LFoundation
${RESULTS_DIR}/runnable/test16096

rm ${dir}/{test16096a.a,test16096}
