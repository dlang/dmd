#!/usr/bin/env bash

name=`basename $0 .sh`
dir=${RESULTS_DIR}/compilable

if [ "${OS}" == "win32" -o "${OS}" == "Windows_NT" ]; then
	file_name=diag12658
	src_file=compilable/${file_name}.d
    output_file=${dir}/${file_name}.out

	$DMD -m${MODEL} ${src_file} test.a 2> ${output_file}.2

    if ! grep -q "Error: Incompatible file: 'test.a'" <"${output_file}.2"; then
        echo "Error: expected diagnostic not found."
        exit 1;
    fi

	$DMD -m${MODEL} ${src_file} test.so 2> ${output_file}.2

    if ! grep -q "Error: Incompatible file: 'test.so'" <"${output_file}.2"; then
        echo "Error: expected diagnostic not found."
        exit 1;
    fi

    rm ${output_file}.2
fi
