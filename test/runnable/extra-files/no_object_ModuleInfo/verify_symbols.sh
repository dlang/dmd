#!/usr/bin/env bash

if ! nm "$1" | grep -q ModuleInfo ; then
    exit 0
fi

exit 1
