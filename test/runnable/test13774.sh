#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test13774.sh.out

$DMD -m${MODEL} -I${src} -lib -od${dir} ${src}${SEP}lib13774a.d || exit 1
$DMD -m${MODEL} -I${src} -lib -od${dir} ${src}${SEP}lib13774b.d ${dir}${SEP}lib13774a${LIBEXT} || exit 1

rm ${dir}/{lib13774a${LIBEXT},lib13774b${LIBEXT}}

echo Success >${output_file}
