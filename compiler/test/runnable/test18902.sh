#!/usr/bin/env bash

# dmd -lib should fail without input sources/object files
if $DMD -m${MODEL} -lib 18902.a; then
    exit 1
else
    [ $? -eq 1 ]
fi
