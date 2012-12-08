#!/usr/bin/env bash

name=`basename $0 .sh`
dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/${name}.sh.out
deps_file="${dmddir}${SEP}${name}.deps"

die()
{
    cat ${output_file}
    echo "---- deps file ----"
    cat ${deps_file}
    echo
    echo "$@"
    rm -f ${output_file} ${deps_file}
    exit 1
}

rm -f ${output_file}

$DMD -m${MODEL} -deps=${deps_file} -Irunnable/imports -o- runnable/extra-files/${name}.d >> ${output_file}
test $? -ne 0 &&
    die "Error compiling"

grep "^${name}.*${name}_default" ${deps_file} | grep -q private ||
    die "Default import protection in dependency file should be 'private'"

grep "^${name}.*${name}_public" ${deps_file} | grep -q public ||
    die "Public import protection in dependency file should be 'public'"

grep "^${name}.*${name}_private" ${deps_file} | grep -q private||
    die "Private import protection in dependency file should be 'private'"

echo "Dependencies file:" >> ${output_file}
cat ${deps_file} >> ${output_file}
echo >> ${output_file}

rm ${deps_file}

