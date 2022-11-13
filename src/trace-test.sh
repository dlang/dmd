#!/bin/bash

FILE="hello.dmdtrace"

make -f posix.mak && ../generated/linux/release/64/dmd -trace="$FILE" ~/hello.d -o-

dmd -i -I../compiler/src -run printTraceHeader.d "$FILE" Tree
dmd -i -I../compiler/src -run printTraceHeader.d "$FILE" TemplateInstances
