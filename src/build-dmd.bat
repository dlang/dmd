@echo off
set OLDHOME=%HOME%
set HOME=%CD%
make clean all -fdmd-win32.mak
set HOME=%OLDHOME%