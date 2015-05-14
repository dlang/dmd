#!/usr/bin/env bash
src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}${SEP}test_utf8_cmdfile.sh.out

rm -f ${output_file}

echo "-of${dir}${SEP}test_utf8_cmdfile${EXE}" > ${dir}${SEP}cmdfile
echo "${src}${SEP}यूनिकोड.d" >> ${dir}${SEP}cmdfile

$DMD @${dir}${SEP}cmdfile || exit 1

rm ${dir}${SEP}{cmdfile,test_utf8_cmdfile${OBJ},test_utf8_cmdfile${EXE}}

echo Success > ${output_file}
