@echo off
set OLDHOME=%HOME%
set HOME=%CD%
make clean unittest -fdmd-win32.mak
set HOME=%OLDHOME%