@echo off
rem Run this batch file from the src folder like this:
rem    vcbuild\builddmd.bat
rem
rem Make sure that you do not have cl.exe from the dmc compiler
rem in your path!

set DEBUG=/Zi
if "%1" == "release" set DEBUG=/O2
make -f win32.mak CC=vcbuild\dmc_cl INCLUDE=vcbuild DEBUG=%DEBUG% dmd.exe
