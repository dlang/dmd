@echo off
echo _MSC_VER > ver.c
cl /nologo /EP ver.c > ver.txt
findstr /v /r /c:"^$" "ver.txt" > "ver_trim.txt"
set /P _MSC_VER=< ver_trim.txt
echo set _MSC_VER=%_MSC_VER%
del ver.c ver.txt ver_trim.txt
