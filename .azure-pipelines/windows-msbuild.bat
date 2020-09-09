setlocal
@echo on
call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" %ARCH%
@echo on

set DMD_DIR=%cd%
if "%CONFIGURATION%" == "" set CONFIGURATION=RelWithAsserts
set PLATFORM=Win32
set MODEL=32mscoff
if "%ARCH%"=="x64" set PLATFORM=x64
if "%ARCH%"=="x64" set MODEL=64
set DMD=%DMD_DIR%\generated\Windows\%CONFIGURATION%\%PLATFORM%\dmd.exe

set VISUALD_INSTALLER=VisualD-%VISUALD_VER%.exe
set N=3
set DM_MAKE=%DMD_DIR%\dm\path\make.exe
set LDC_DIR=%DMD_DIR%\ldc2-%LDC_VERSION%-windows-multilib

REM take the first found cl.exe, in case there was already one in the path when vcvarsall.bat was called
FOR /F "tokens=* USEBACKQ" %%F IN (`where cl.exe`) DO (SET MSVC_CC=%%~fsF && goto CC_DONE)
:CC_DONE
FOR /F "tokens=* USEBACKQ" %%F IN (`where lib.exe`) DO (SET MSVC_AR=%%~fsF)
REM this returns two lines (GNU's link.exe is on the second line)
REM Just take the first one
FOR /F "tokens=* USEBACKQ" %%F IN (`where link.exe`) DO (SET MSVC_LD=%%~fsF
  GOTO :Next)
:Next
FOR /F "tokens=* USEBACKQ" %%F IN (`where make.exe`) DO (SET GNU_MAKE=%%~fsF)

REM expose dm_make as default make
set PATH=%DMD_DIR%\dm\path;%DMD_DIR%\tools;%PATH%
dir "%DMD_DIR%\tools"
"%DMD_DIR%\tools\grep.exe" --version
echo %PATH%
grep --version

.\%VISUALD_INSTALLER% /S
REM configure DMD path
if "%D_COMPILER%" == "dmd" reg add "HKLM\SOFTWARE\DMD" /v InstallationFolder /t REG_SZ /d "%DMD_DIR%" /reg:32 /f
REM configure LDC path
if "%D_COMPILER%" == "ldc" reg add "HKLM\SOFTWARE\LDC" /v InstallationFolder /t REG_SZ /d "%LDC_DIR%" /reg:32 /f

REM build via VS projects with LDC
cd src
if "%D_COMPILER%" == "ldc" set LDC_ARGS=%LDC_ARGS% /p:DCompiler=LDC
msbuild /target:dmd /p:Configuration=%CONFIGURATION% /p:Platform=%PLATFORM% %LDC_ARGS% vcbuild\dmd.sln || exit /B 1

%DMD% --version
grep --version

set DMD_TESTS=all
set DRUNTIME_TESTS=test_all
cd "%DMD_DIR%"
if not "%C_RUNTIME%" == "mingw" goto not_mingw
    rem install recent LLD and mingw libraries to built dmd
    if exist "%DMD_DIR%\generated\Windows\%CONFIGURATION%\%PLATFORM%\lld-link.exe" goto lld_exists
    powershell -command "& { iwr http://downloads.dlang.org/other/lld-link-9.0.0-seh.zip -OutFile lld.zip }" || exit /B 11
    7z x lld.zip -o%DMD_DIR%\generated\Windows\%CONFIGURATION%\%PLATFORM% || exit /B 12
    :lld_exists

    if exist "%DMD_DIR%\mingw\dmd2\windows\lib%MODEL%\mingw\kernel32.lib" goto mingw_exists
    powershell -command "& { iwr https://github.com/dlang/installer/releases/download/mingw-libs-7.0.0-2/mingw-libs-7.0.0-2.zip -OutFile mingw.zip }" || exit /B 13
    7z x mingw.zip -o%DMD_DIR%\mingw || exit /B 14
    :mingw_exists
    
    set DFLAGS=-mscrtlib=msvcrt120
    set LIB=%DMD_DIR%\mingw\dmd2\windows\lib%MODEL%\mingw
    set REQUIRED_ARGS=-mscrtlib=msvcrt120 "-L/LIBPATH:%DMD_DIR%\mingw\dmd2\windows\lib%MODEL%\mingw"
    rem delete C++ ABI tests
    set DMD_TESTS=runnable compilable fail_compilation dshell
    rem FIXME: debug info incomplete when linking through lld-link
    del test\runnable\testpdb.d

    set DRUNTIME_TESTS=test_mingw
:not_mingw

REM Check: run druntime unittests
cd "%DMD_DIR%\..\druntime"
"%DM_MAKE%" -f win64.mak MODEL=%MODEL% "DMD=%DMD%" "VCDIR=%VCINSTALLDIR%." "CC=%MSVC_CC%" "MAKE=%DM_MAKE%" target || exit /B 2
echo "[DRUNTIME] running tests..."
"%DM_MAKE%" -f win64.mak MODEL=%MODEL% "DMD=%DMD%" "VCDIR=%VCINSTALLDIR%." "CC=%MSVC_CC%" "MAKE=%DM_MAKE%" unittest || exit /B 3
"%DM_MAKE%" -f win64.mak MODEL=%MODEL% "DMD=%DMD%" "VCDIR=%VCINSTALLDIR%." "CC=%MSVC_CC%" "MAKE=%DM_MAKE%" %DRUNTIME_TESTS% || exit /B 4

REM Check: build phobos
cd "%DMD_DIR%\..\phobos"
"%DM_MAKE%" -f win64.mak MODEL=%MODEL% "DMD=%DMD%" "VCDIR=%VCINSTALLDIR%." "CC=%MSVC_CC%" "AR=%MSVC_AR%" "MAKE=%DM_MAKE%" || exit /B 5

REM Run DMD testsuite
cd "%DMD_DIR%\test"
set ARGS=-O -inline -g
set OS=windows
set CC=cl.exe
set DMD_MODEL=%PLATFORM%
set BUILD=%CONFIGURATION%
if "%BUILD%" == "RelWithAsserts" (
    set BUILD=Release
    mkdir %DMD_DIR%\generated\Windows\Release\%PLATFORM%
    xcopy %DMD_DIR%\generated\Windows\RelWithAsserts\%PLATFORM% %DMD_DIR%\generated\Windows\Release\%PLATFORM% /s
)
set HOST_DMD=%DMD_DIR%\dmd2\windows\bin\dmd.exe
del phobos%MODEL%.lib

"%HOST_DMD%" -m%MODEL% -i run.d || exit /B 6
run.exe %DMD_TESTS% || exit /B 6

rem FIXME: lld-link fails to link phobos unittests ("error: relocation against symbol in discarded section: __TMP2427")
if "%C_RUNTIME%" == "mingw" exit /B 0

cd "%DMD_DIR%\..\phobos"
REM Check: build phobos unittests
if "%D_COMPILER%_%MODEL%" == "ldc_64" copy %LDC_DIR%\lib64\libcurl.dll .
if "%D_COMPILER%_%MODEL%" == "ldc_32mscoff" copy %LDC_DIR%\lib32\libcurl.dll .
if "%D_COMPILER%_%MODEL%" == "dmd_64" copy %DMD_DIR%\dmd2\windows\bin64\libcurl.dll .
if "%D_COMPILER%_%MODEL%" == "dmd_32mscoff" copy %DMD_DIR%\dmd2\windows\bin\libcurl.dll .
"%DM_MAKE%" -f win64.mak unittest MODEL=%MODEL% "DMD=%DMD%" "VCDIR=%VCINSTALLDIR%." "CC=%MSVC_CC%" "MAKE=%DM_MAKE%"
