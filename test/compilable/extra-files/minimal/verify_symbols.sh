#!/usr/bin/env bash

# ensure no ModuleInfo or TypeInfo related code was generated
if ! nm "$1" | grep -q 'ModuleInfo\|_d_dso_registry\__start_minfo\|__stop_minfo\|TypeInfo' ; then
    # ensure no exception handling code was generated
    if ! objdump -h "$1" | grep -q ".eh_frame" ; then
        exit 0
    fi
fi

exit 1
