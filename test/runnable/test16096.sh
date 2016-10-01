#!/usr/bin/env bash

set -e

src=runnable/extra-files
dir=${RESULTS_DIR}/runnable
output_file=${dir}/test16096.sh.out

if [ "$OS" != 'osx' ] || [ "$MODEL" != '64' ]; then
    exit 0
fi

function teardown {
    if [ "$?" -ne 0 ] && [ -r "$output_file" ]; then
        cat "${output_file}" 1>&2
    fi
    rm -f "${output_file}"
}

trap teardown EXIT

$DMD -I${src} -of${dir}${SEP}test16096a.a -lib ${src}/test16096a.d >> "${output_file}" 2>&1
$DMD -I${src} -of${dir}${SEP}test16096 ${src}/test16096.d ${dir}/test16096a.a -L-framework -LFoundation >> "${output_file}" 2>&1
${RESULTS_DIR}/runnable/test16096 >> "${output_file}" 2>&1

rm ${dir}/{test16096a.a,test16096}
