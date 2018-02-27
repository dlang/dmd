#!/usr/bin/env bash

dir=${RESULTS_DIR}/compilable

if [ "${OS}" == "win32" -o "${OS}" == "Windows_NT" ]; then
    kinds=( main winmain dllmain )
else
    kinds=( main )
fi

for kind in "${kinds[@]}"
do
	file_name=${TEST_NAME}${kind}
	src_file=compilable/extra-files/${file_name}.d
	expect_file=compilable/extra-files/${file_name}.out
	output_file=${dir}/${file_name}.out

	rm -f ${output_file}{,.2}

	$DMD -m${MODEL} -v -o- ${src_file} > ${output_file}
	grep "^entry     ${kind}" ${output_file} > ${output_file}.2
	if [ `wc -c ${output_file}.2 | while read a b; do echo $a; done` -eq 0 ]; then
		echo "Error: not found expected entry point '${kind}' in ${src_file}"
		exit 1;
	fi

	rm ${output_file}{,.2}
done

echo Success
