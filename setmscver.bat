@echo off
echo _MSC_VER > ver.c
cl /nologo /EP ver.c > ver_raw.txt
findstr /v /r /c:"^$" "ver_raw.txt" > "ver.txt"
set /P _MSC_VER=< ver.txt
echo set _MSC_VER=%_MSC_VER%
del ver.c ver_raw.txt
