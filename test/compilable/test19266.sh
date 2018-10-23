#!/usr/bin/env bash

if [ "${OS}" == "win32" -o "${OS}" == "win64" -o "${OS}" == "win32mscoff" ]; then 
   # break out of bash to get Windows paths
   cmd //c $(echo $DMD | tr / \\) -c \\\\.\\%CD%\\compilable\\extra-files\\test19266.d -deps=nul:
fi
