#!/usr/bin/env bash

name=`basename $0 .sh`
dir=${RESULTS_DIR}${SEP}compilable

file_name=rdmdimport
src_file=compilable${SEP}imports${SEP}${file_name}.d
output_file=${dir}${SEP}${file_name}.${OBJ}

# build the dependency
$DMD -m${MODEL} -c ${src_file} -of${output_file}

main_file=compilable${SEP}extra-files${SEP}rdmd_exclude.d

# build the main file, but only link to the dependency
$RDMD --force -m${MODEL} -Icompilable --exclude=imports ${output_file} ${main_file}

rm -f ${output_file}
