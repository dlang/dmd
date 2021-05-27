#!/bin/bash
obj_file=${OUTPUT_BASE}_0.o

if nm "${obj_file}" | grep -q "ctfeOnly";
then
    exit 1
fi
