#!/usr/bin/env bash

name=`basename $0 .sh`
dir=${RESULTS_DIR}/compilable


# Test module without module declaration
file_name=test3541a
src_file=compilable/extra-files/${file_name}.d
out_file=${dir}/${file_name}${OBJ}

$DMD -m${MODEL} -c -oq ${src_file} -of${out_file}
if [ ! -f ${out_file} ]; then
    echo "Error: Object file not found '${out_file}'"
    exit 1;
fi

# Test module with module declaration
file_name=test3541b
src_file=compilable/extra-files/${file_name}.d
out_file=${dir}/${file_name}${OBJ}

$DMD -m${MODEL} -c -oq ${src_file} -of${out_file}
if [ ! -f ${out_file} ]; then
    echo "Error: Object file not found '${out_file}'"
    exit 1;
fi

# Test module with module declaration that has a package
file_name=test3541c
src_file=compilable/extra-files/${file_name}.d
out_file=${dir}/foo.${file_name}${OBJ}

$DMD -m${MODEL} -c -oq ${src_file} -of${out_file}
if [ ! -f ${out_file} ]; then
    echo "Error: Object file not found '${out_file}'"
    exit 1;
fi
