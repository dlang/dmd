#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

make -C ../../.. -f posix.mak

TRACEFILE="hello"

../../../generated/linux/release/64/dmd -trace="$TRACEFILE" hello.d -o-

# dmd -i -I../compiler/src -run printTraceHeader.d "$FILE".dmd_trace Tree
dmd -i -I../../src -run printTraceHeader.d "$TRACEFILE".dmd_trace TemplateInstances
