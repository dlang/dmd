#!/usr/bin/env bash

name="depsprot"
dir=${RESULTS_DIR}/runnable
dmddir=${RESULTS_DIR}${SEP}runnable
deps_file="${dmddir}${SEP}${name}.deps"

# custom error handling
set +eo pipefail

die()
{
    echo "---- deps file ----"
    cat ${deps_file}
    echo
    echo "$@"
    rm -f ${deps_file}
    exit 1
}

$DMD -m${MODEL} -deps=${deps_file} -Irunnable/imports -o- runnable/extra-files/${name}.d
test $? -ne 0 &&
    die "Error compiling"

grep "^${name}.*${name}_default" ${deps_file} | grep -q private ||
    die "Default import protection in dependency file should be 'private'"

grep "^${name}.*${name}_public" ${deps_file} | grep -q public ||
    die "Public import protection in dependency file should be 'public'"

grep "^${name}.*${name}_private" ${deps_file} | grep -q private||
    die "Private import protection in dependency file should be 'private'"

echo "Dependencies file:"
cat ${deps_file}
echo

rm ${deps_file}
