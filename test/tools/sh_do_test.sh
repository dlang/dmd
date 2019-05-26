#!/usr/bin/env bash

set -euo pipefail

if [ "${RESULTS_DIR}" == "" ]; then
    echo Note: this program is normally called through the Makefile, it
    echo is not meant to be called directly by the user.
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

################################################################################
# Exported variables
################################################################################

source "$DIR/exported_vars.sh"
source "$DIR/common_funcs.sh"

################################################################################

# Generated variables
_script_name="${TEST_DIR}/${TEST_NAME}.sh"
_output_file="${RESULTS_DIR}/${_script_name}.out"

echo " ... ${_script_name}"
rm -f "${_output_file}"
mkdir -p ${RESULTS_TEST_DIR}

function finish {
    # reset output stream
    set +x
    exec 1>&40
    exec 2>&41

    if [ "$1" -ne 0 ]; then
        echo "=============================="
        echo "Test ${_script_name} failed. The logged output:"
        cat "${_output_file}"

        echo "=============================="
        echo "Test ${_script_name} failed. The xtrace output:"
        cat "${_output_file}.log"

        rm -rf "${_output_file}"
        exit $1
    fi
}
trap 'finish $?' INT TERM EXIT

# redirect stdout + stderr to the output file + keep a reference to the std{out,err} streams for later
exec 40>&1
exec 41>&2
exec 1> "${_output_file}"
exec 2>&1

# log all a verbose xtrace to a temporary file which is only displayed when an error occurs
exec 42> "${_output_file}.log"
export BASH_XTRACEFD=42

# fail on errors and undefined variables
set -euo pipefail

# activate xtrace logging for the to-be-called shell script
set -x

source "${_script_name}"
