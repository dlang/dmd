#!/usr/bin/env bash

if [ "${RESULTS_DIR}" == "" ]; then
    echo Note: this program is normally called through the Makefile, it
    echo is not meant to be called directly by the user.
    exit 1
fi

# TEST_DIR should be one of compilable, fail_compilation or runnable
export TEST_DIR=$1
export TEST_NAME=$2
script_name=${TEST_DIR}/${TEST_NAME}.sh

echo " ... ${script_name}"

output_file=${RESULTS_DIR}/${script_name}.out
rm -f ${output_file}

./${script_name} > ${output_file}  2>&1
if [ $? -ne 0 ]; then
    # duplicate d_do_test output
    echo >> ${output_file}
    echo ============================== >> ${output_file}
    echo Test ${script_name} failed >> ${output_file}

    echo Test ${script_name} failed. The logged output:
    cat ${output_file}
    exit 1
fi
