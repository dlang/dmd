@echo off
rem echo called with: %*
set def=/DLITTLE_ENDIAN=1 /D__pascal= /D_M_I86=1
rem copt defaults to linker options
set copt=/nologo /link /LARGEADDRESSAWARE
set cmd=
:next
if "%1" == "" goto done
rem echo %1

set opt=%1
rem add longdouble.c and strtold.c to the build, they are not in the makefile
if "%opt%" == "toir"     set opt=%opt%.c backend\strtold.c root\longdouble.c
if "%opt%" == "toir.obj" set opt=%opt% strtold.obj longdouble.obj
rem remove includes after ";"
if "%opt%" == "tk" set opt=/Itk
rem -DX=1 split into two arguments
if "%opt%" == "1" goto shift

if "%opt:~0,1%" == "-" goto opt
if "%opt:~0,1%" == "/" goto opt

if "%opt:~-2%" == ".c" goto isC
if "%opt:~-4%" == ".obj" goto add
set opt=%opt%.c
:isC
set copt=/TP /Ivcbuild /Iroot /nologo /EHsc /Zp1 %def%
goto add

:opt
if "%opt:~0,2%" == "-o" (
	if "%opt:~-4%" == ".exe" set opt=/Fe%opt:~2%
	if "%opt:~-4%" == ".obj" set opt=/Fo%opt:~2%
)
rem echo %opt%
rem if "%opt:~0,2%" == "-I" goto shift

if "%opt%" == "-e" goto shift
if "%opt%" == "-Ae" goto shift
if "%opt%" == "-Ar" goto shift
if "%opt%" == "-mn" goto shift
if "%opt%" == "-cpp" goto shift
if "%opt%" == "-wx" goto shift
if "%opt%" == "-m32" goto shift

:add
set cmd=%cmd% %opt%

:shift
shift
goto next

:done
rem echo cl %copt% %cmd%
cl %cmd% %copt% 
