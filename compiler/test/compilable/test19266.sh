#!/usr/bin/env bash

if [ "${OS}" == "windows" -and -not -z WSL_DISTRO_NAME ]; then
   # break out of bash to get Windows paths
   # use cmd.exe instead of cmd to work from WSL
   cmd.exe /c $(echo $DMD | tr / \\) -c \\\\.\\%CD%\\compilable\\extra-files\\test19266.d -deps=nul:
fi
