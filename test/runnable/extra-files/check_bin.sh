#!/usr/bin/env bash

if [ "$2" == "HAS" ]; then
    GREP_OPTION=
elif [ "$2" == "DOES_NOT_HAVE" ]; then
    GREP_OPTION=-v
else
    echo Unknown option "$2"
    exit 1
fi

if [ ${OS} != "linux" ]; then
    echo Skipping checkbin $2 $3 because os $OS is not linux
    exit 0
fi

objdump -t "$1" | grep -q $GREP_OPTION "$3"
