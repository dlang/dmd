@echo off
set OLDHOME=%HOME%
set HOME=%CD%
make clean release doc install -fdmd-win32.mak
make clean debug install -fdmd-win32.mak
make clean -fdmd-win32.mak
set HOME=%OLDHOME%