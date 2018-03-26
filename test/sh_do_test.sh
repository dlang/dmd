#!/usr/bin/env bash

set -euo pipefail

if [ "${RESULTS_DIR}" == "" ]; then
    echo Note: this program is normally called through the Makefile, it
    echo is not meant to be called directly by the user.
    exit 1
fi

################################################################################
# Exported variables
################################################################################

export TEST_DIR=$1 # TEST_DIR should be one of compilable, fail_compilation or runnable
export TEST_NAME=$2 # name of the test, e.g. test12345
export RESULTS_TEST_DIR=${RESULTS_DIR}/${TEST_DIR} # reference to the resulting test_dir folder, e.g .test_results/runnable
export OUTPUT_BASE=${RESULTS_TEST_DIR}/${TEST_NAME} # reference to the resulting files without a suffix, e.g. test_results/runnable/test123
export EXTRA_FILES=${TEST_DIR}/extra-files # reference to the extra files directory

if [ "$OS" == "win32" ] || [ "$OS" == "win64" ]; then
    export LIBEXT=.lib
    export OBJ=.obj
else
    export LIBEXT=.a
    export OBJ=.o
fi

################################################################################

# Generated variables
script_name="${TEST_DIR}/${TEST_NAME}.sh"
output_file="${RESULTS_DIR}/${script_name}.out"

echo " ... ${script_name}"
rm -f "${output_file}"
mkdir -p ${RESULTS_TEST_DIR}

function finish {
    # reset output stream
    set +x
    exec 1>&40
    exec 2>&41

    if [ "$1" -ne 0 ]; then
        echo "=============================="
        echo "Test ${script_name} failed. The logged output:"
        cat "${output_file}"

        echo "=============================="
        echo "Test ${script_name} failed. The xtrace output:"
        cat "${output_file}.log"

        rm -rf "${output_file}"
        exit $?
    fi
}
trap 'finish $?' INT TERM EXIT

# redirect stdout + stderr to the output file + keep a reference to the std{out,err} streams for later
exec 40>&1
exec 41>&2
exec 1> "${output_file}"
exec 2>&1

# log all a verbose xtrace to a temporary file which is only displayed when an error occurs
exec 42> "${output_file}.log"
export BASH_XTRACEFD=42

# fail on errors and undefined variables
set -euo pipefail

# activate xtrace logging for the to-be-called shell script
set -x

source "${script_name}"
