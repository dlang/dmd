#!/usr/bin/env bash

if [ "${OS}" == "windows" ]; then
   # break out of bash to get Windows paths
   # use cmd.exe instead of cmd to work from WSL
   # use MSYS_NO_PATHCONV=1 to disable /c -> c:\ translation in git bash
   MSYS_NO_PATHCONV=1 cmd.exe /c $(echo $DMD | tr / \\) -c \\\\.\\%CD%\\compilable\\extra-files\\test19266.d -deps=nul:
fi
