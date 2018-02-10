#!/usr/bin/env bash

set -ueo pipefail

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/test13742.sh.out

if [ $OS == "win32" -o  $OS == "win64" ]; then
    LIBEXT=.lib
    OBJ=.obj
else
    LIBEXT=.a
    OBJ=.o
fi

$DMD -m${MODEL} -I${src} -lib -cov -of${dir}${SEP}test13742${LIBEXT} ${src}${SEP}lib13742a.d ${src}${SEP}lib13742b.d
$DMD -m${MODEL} -I${src} -cov -of${dir}${SEP}test13742${EXE} ${src}${SEP}test13742.d ${dir}${SEP}test13742${LIBEXT}

${RESULTS_DIR}/runnable/test13742${EXE} --DRT-covopt=dstpath:${dir}${SEP}

rm ${RESULTS_DIR}/runnable/{runnable-extra-files-{lib13742a,lib13742b,test13742}.lst,test13742{${OBJ},${LIBEXT},${EXE}}}

echo Success > ${output_file}
