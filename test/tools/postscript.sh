#!/usr/bin/env bash
# A wrapper for all postscript files which sets `-euo pipefail`

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

if [ -z ${RESULTS_DIR+x} ]; then
    RESULTS_DIR="$DIR/../test_results"
    echo >&2 Warning [$0]: RESULTS_DIR not set, this run will use RESULTS_DIR="$RESULTS_DIR"
fi

script_file="$1"
shift

# Was the OS set?
if [ -z ${OS+x} ]; then
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS=linux
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS=osx
    elif [[ "$OSTYPE" == "cygwin" ]]; then
        OS=windows
    elif [[ "$OSTYPE" == "msys" ]]; then
        OS=windows
    elif [[ "$OSTYPE" == "win32" ]]; then
        OS=win32
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        OS=freebsd
    else
        # Unknown, assume Windows
        OS=windows
    fi
    echo >&2 Warning [$0]: OS not set, this run will use OS="$OS"
fi

# export common variables
source "$DIR/exported_vars.sh"

# Remove TEST_DIR and TEST_NAME
shift
shift

# called scripts should fail on errors and undefined variables
set -euo pipefail
set -x

source "${script_file}"
