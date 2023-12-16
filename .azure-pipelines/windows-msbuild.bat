setlocal
@echo on

:: put bash and GNU tools in front of PATH
set PATH=C:\Program Files\Git\usr\bin;%PATH%

:: now set up MSVC environment (=> first link.exe etc. in PATH is MSVC's, not GNU's)
call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" %ARCH%
@echo on

set DMD_DIR=%cd%
if "%CONFIGURATION%" == "" set CONFIGURATION=RelWithAsserts
set PLATFORM=Win32
set MODEL=32
if "%ARCH%"=="x64" set PLATFORM=x64
if "%ARCH%"=="x64" set MODEL=64
set DMD=%DMD_DIR%\generated\Windows\%CONFIGURATION%\%PLATFORM%\dmd.exe

set VISUALD_INSTALLER=VisualD-%VISUALD_VER%.exe
set N=3
set DM_MAKE=%DMD_DIR%\dm\path\make.exe
set LDC_DIR=%DMD_DIR%\ldc2-%LDC_VERSION%-windows-multilib

if "%D_COMPILER%" == "ldc" set HOST_DMD=%LDC_DIR%\bin\ldmd2.exe
if "%D_COMPILER%" == "dmd" set HOST_DMD=%DMD_DIR%\dmd2\windows\bin\dmd.exe

set MSVC_CC=cl.exe
FOR /F "tokens=* USEBACKQ" %%F IN (`where lib.exe`) DO (SET MSVC_AR=%%~fsF)

REM add grep to PATH
set PATH=%DMD_DIR%\tools;%PATH%
echo %PATH%
grep --version

.\%VISUALD_INSTALLER% /S
REM configure DMD path
if "%D_COMPILER%" == "dmd" reg add "HKLM\SOFTWARE\DMD" /v InstallationFolder /t REG_SZ /d "%DMD_DIR%" /reg:32 /f
REM configure LDC path
if "%D_COMPILER%" == "ldc" reg add "HKLM\SOFTWARE\LDC" /v InstallationFolder /t REG_SZ /d "%LDC_DIR%" /reg:32 /f

echo [STEP]: Building DMD via VS projects
cd compiler\src
if "%D_COMPILER%" == "ldc" set LDC_ARGS=%LDC_ARGS% /p:DCompiler=LDC
msbuild /target:dmd /p:Configuration=%CONFIGURATION% /p:Platform=%PLATFORM% %LDC_ARGS% vcbuild\dmd.sln || exit /B 1
%DMD% --version

echo [STEP]: Building druntime
make -j%N% -C "%DMD_DIR%\druntime" MODEL=%MODEL% "DMD=%DMD%" || exit /B 2

echo [STEP]: Building phobos
cd "%DMD_DIR%\..\phobos"
"%DM_MAKE%" -f win64.mak MODEL=%MODEL% "DMD=%DMD%" "VCDIR=%VCINSTALLDIR%." "CC=%MSVC_CC%" "AR=%MSVC_AR%" "MAKE=%DM_MAKE%" "DRUNTIME=%DMD_DIR%\druntime" "DRUNTIMELIB=%DMD_DIR%\generated\windows\release\%MODEL%\druntime.lib" || exit /B 3
:: The expected Phobos filename for 32-bit COFF is phobos32mscoff.lib, not phobos32.lib.
if "%MODEL%" == "32" ren phobos32.lib phobos32mscoff.lib || exit /B 3

echo [STEP]: Building run.d testrunner and its tools
REM needs to be done before tampering with LIB and DFLAGS env variables (affecting the ldmd2 host compiler too)
cd "%DMD_DIR%\compiler\test"
"%HOST_DMD%" -m%MODEL% -g -i run.d || exit /B 4
run.exe tools "BUILD=%CONFIGURATION%" "DMD_MODEL=%PLATFORM%" || exit /B 4

:: FIXME: skip unit_tests temporarily due to unclear (spurious?) CI failures
:: set DMD_TESTS=all
set DMD_TESTS=runnable runnable_cxx compilable fail_compilation dshell
set DRUNTIME_TESTS_TARGET=unittest
cd "%DMD_DIR%"
if not "%C_RUNTIME%" == "mingw" goto not_mingw
    rem install recent LLD and mingw libraries to built dmd
    if exist "%DMD_DIR%\generated\Windows\%CONFIGURATION%\%PLATFORM%\lld-link.exe" goto lld_exists
    powershell -command "& { iwr https://downloads.dlang.org/other/lld-link-9.0.0-seh.zip -OutFile lld.zip }" || exit /B 11
    7z x lld.zip -o%DMD_DIR%\generated\Windows\%CONFIGURATION%\%PLATFORM% || exit /B 12
    :lld_exists

    if exist "%DMD_DIR%\mingw\dmd2\windows\lib%MODEL%\mingw\kernel32.lib" goto mingw_exists
    powershell -command "& { iwr https://github.com/dlang/installer/releases/download/mingw-libs-8.0.0/mingw-libs-8.0.0.zip -OutFile mingw.zip }" || exit /B 13
    7z x mingw.zip -o%DMD_DIR%\mingw || exit /B 14
    :mingw_exists

    set DFLAGS=-mscrtlib=msvcrt120
    if "%MODEL%" == "32" (
        set LIB=%DMD_DIR%\mingw\dmd2\windows\lib32mscoff\mingw
    ) else (
        set LIB=%DMD_DIR%\mingw\dmd2\windows\lib%MODEL%\mingw
    )
    set REQUIRED_ARGS=-mscrtlib=msvcrt120 "-L/LIBPATH:%LIB%"
    rem skip runnable_cxx tests (incompatible MSVC runtime versions - 2017 (cl.exe) vs. 2013)
    rem FIXME: unit_tests excluded too, see above
    set DMD_TESTS=runnable compilable fail_compilation dshell
    rem FIXME: debug info incomplete when linking through lld-link
    del compiler\test\runnable\testpdb.d
    rem Somehow, and only for the MinGW CI job, building the druntime unittest runner in release mode can take ages (~15 mins with -j1)
    set DRUNTIME_TESTS_TARGET=unittest-debug
:not_mingw

echo [STEP]: Building and running druntime tests
cd "%DMD_DIR%\druntime"
make -j%N% MODEL=%MODEL% "DMD=%DMD%" "CC=%MSVC_CC%" %DRUNTIME_TESTS_TARGET% || exit /B 5

echo [STEP]: Running DMD testsuite
cd "%DMD_DIR%\compiler\test"
run.exe --environment --jobs=%N% %DMD_TESTS% "ARGS=-O -inline -g" "BUILD=%CONFIGURATION%" "DMD_MODEL=%PLATFORM%" "CC=%MSVC_CC%" || exit /B 6

echo [STEP]: Building and running Phobos unittests
rem FIXME: lld-link fails to link phobos unittests ("error: relocation against symbol in discarded section: __TMP2427")
if "%C_RUNTIME%" == "mingw" exit /B 0
cd "%DMD_DIR%\..\phobos"
if "%D_COMPILER%_%MODEL%" == "ldc_64" copy %LDC_DIR%\lib64\libcurl.dll .
if "%D_COMPILER%_%MODEL%" == "ldc_32" copy %LDC_DIR%\lib32\libcurl.dll .
if "%D_COMPILER%_%MODEL%" == "dmd_64" copy %DMD_DIR%\dmd2\windows\bin64\libcurl.dll .
if "%D_COMPILER%_%MODEL%" == "dmd_32" copy %DMD_DIR%\dmd2\windows\bin\libcurl.dll .
"%DM_MAKE%" -f win64.mak MODEL=%MODEL% "DMD=%DMD%" "VCDIR=%VCINSTALLDIR%." "CC=%MSVC_CC%" "MAKE=%DM_MAKE%" "DRUNTIME=%DMD_DIR%\druntime" "DRUNTIMELIB=%DMD_DIR%\generated\windows\release\%MODEL%\druntime.lib" unittest || exit /B 7
