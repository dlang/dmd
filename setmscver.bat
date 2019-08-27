@echo off
echo _MSC_VER > ver.c
cl /nologo /EP ver.c > ver_raw.txt
findstr /v /r /c:"^$" "ver_raw.txt" > "ver.txt"
set /P _MSC_VER=< ver.txt
echo set _MSC_VER=%_MSC_VER%
if exist cflags.txt del /q cflags.txt
if exist dflags.txt del /q dflags.txt
if exist add_tests.txt del /q add_tests.txt
if %_MSC_VER% GTR 1900 echo /std:c++17 > cflags.txt
if %_MSC_VER% GTR 1900 echo -extern-std=c++17 > dflags.txt
if %_MSC_VER% GTR 1900 echo string_view > add_tests.txt
del ver.c ver_raw.txt
