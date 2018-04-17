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
        exit $1
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
