#!/usr/bin/env bash

if ! nm "$1" | grep -q 'ModuleInfo\|_d_dso_registry\__start_minfo\|__stop_minfo' ; then
    exit 0
fi

exit 1
