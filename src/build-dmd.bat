@echo off
set OLDHOME=%HOME%
set HOME=%CD%
make clean -fdmd-win32.mak
make lib install -fdmd-win32.mak
make clean -fdmd-win32.mak
set HOME=%OLDHOME%