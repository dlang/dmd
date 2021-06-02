#!/usr/bin/env bash

if [ "${OS}" == "windows" ]; then
   # break out of bash to get Windows paths
   cmd //c $(echo $DMD | tr / \\) -c \\\\.\\%CD%\\compilable\\extra-files\\test19266.d -deps=nul:
fi
