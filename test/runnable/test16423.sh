#!/usr/bin/env bash

set -e

if [ $OS == "win32" -o $OS == "win64" ]; then
  libext=.lib
else
  libext=.a
fi

filename_ext=`basename $0`
filename="${filename_ext%.*}"
src=runnable/extra-files
dir=${RESULTS_DIR}/runnable
output_file=${dir}/${filename_ext}.out

$DMD -m${MODEL} -I${src} -of${dir}${SEP}${filename}lib${libext} -lib ${src}/${filename}lib.d
$DMD -m${MODEL} -I${src} -of${dir}${SEP}${filename} ${src}/${filename}main.d ${dir}/${filename}lib${libext}
${RESULTS_DIR}/runnable/${filename}

rm ${dir}/{${filename}lib${libext},${filename}}

echo Success > "$output_file"
