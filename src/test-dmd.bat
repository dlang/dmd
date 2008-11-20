@echo off
set OLDHOME=%HOME%
set HOME=%CD%
make clean -fdmd-win32.mak
make unittest -fdmd-win32.mak
make clean -fdmd-win32.mak
set HOME=%OLDHOME%