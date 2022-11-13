#!/bin/bash

TRACEFILE="hello.dmdtrace"

make -f posix.mak && ../generated/linux/release/64/dmd -trace="$TRACEFILE" ~/hello.d -o-

# dmd -i -I../compiler/src -run printTraceHeader.d "$FILE".dmd_trace Tree
dmd -i -I../compiler/src -run printTraceHeader.d "$TRACEFILE".dmd_trace TemplateInstances
