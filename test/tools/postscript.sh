#!/usr/bin/env bash
# A wrapper for all postscript files which sets `-euo pipefail`

set -euo pipefail

script_file="$1"
shift

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# export common variables
source "$DIR/exported_vars.sh"

# Remove TEST_DIR and TEST_NAME
shift
shift

# called scripts should fail on errors and undefined variables
set -euo pipefail
set -x

source "${script_file}"
