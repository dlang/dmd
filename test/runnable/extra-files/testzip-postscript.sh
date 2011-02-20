#!/usr/bin/env bash

testzipfile=${RESULTS_DIR}/runnable/testzip-out.zip

if [ ! -f ${testzipfile} ]; then
    exit 1;
fi

unzip -l ${testzipfile}
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${testzipfile}
