#!/bin/bash
obj_file=${OUTPUT_BASE}_0."${OBJ}"

if [ "${OS}" = "windows"]; then
    if DUMPBIN /ALL "${obj_file}" | grep -q "ctfeOnly"; then
        exit 1
    fi
else
    if nm "${obj_file}" | grep -q "ctfeOnly"; then
        exit 1
    fi
fi
