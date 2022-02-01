# Makefile to build D runtime library druntime64.lib for Win64

MODEL=64

# Visual Studio 2019
#VCDIR=\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.27.29110
#SDKDIR=\Program Files (x86)\Windows Kits\10\Include\10.0.18362.0
# Visual Studio 2015 and before
VCDIR=\Program Files (x86)\Microsoft Visual Studio 10.0\VC
SDKDIR=\Program Files (x86)\Microsoft SDKs\Windows\v7.0A

DMD_DIR=..\dmd
BUILD=release
OS=windows
DMD=$(DMD_DIR)\generated\$(OS)\$(BUILD)\$(MODEL)\dmd

# Visual Studio 2017/2019
#BINDIR=$(VCDIR)\bin\Hostx64\x64
# Visual Studio 2015 and before
BINDIR=$(VCDIR)\bin\amd64

CC=$(BINDIR)\cl
LD=$(BINDIR)\link
AR=$(BINDIR)\lib
CP=cp

DOCDIR=doc
IMPDIR=import

MAKE=make
HOST_DMD=dmd

DFLAGS=-m$(MODEL) -conf= -O -release -preview=dip1000 -preview=fieldwise -preview=dtorfields -inline -w -Isrc -Iimport
UDFLAGS=-m$(MODEL) -conf= -O -release -preview=dip1000 -preview=fieldwise -w -version=_MSC_VER_$(_MSC_VER) -Isrc -Iimport
DDOCFLAGS=-conf= -c -w -o- -Isrc -Iimport -version=CoreDdoc

UTFLAGS=-version=CoreUnittest -unittest -checkaction=context

#CFLAGS=/O2 /I"$(VCDIR)"\INCLUDE /I"$(SDKDIR)"\Include
CFLAGS=/Z7 /I"$(VCDIR)"\INCLUDE /I"$(SDKDIR)"\Include
# Visual Studio 2019
#CFLAGS=/Z7 /I"$(VCDIR)"\include /I"$(SDKDIR)"\ucrt

DRUNTIME_BASE=druntime$(MODEL)
DRUNTIME=lib\$(DRUNTIME_BASE).lib

# do not preselect a C runtime (extracted from the line above to make the auto tester happy)
CFLAGS=$(CFLAGS) /Zl

DOCFMT=

target: import copydir copy $(DRUNTIME)

$(mak\COPY)
$(mak\DOCS)
$(mak\IMPORTS)
$(mak\SRCS)

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)

OBJS= errno_c_$(MODEL).obj
OBJS_TO_DELETE= errno_c_$(MODEL).obj

######################## Header file generation ##############################

import:
	"$(MAKE)" -f mak/WINDOWS import DMD="$(DMD)" HOST_DMD="$(HOST_DMD)" MODEL=$(MODEL) IMPDIR="$(IMPDIR)"

copydir:
	"$(MAKE)" -f mak/WINDOWS copydir DMD="$(DMD)" HOST_DMD="$(HOST_DMD)" MODEL=$(MODEL) IMPDIR="$(IMPDIR)"

copy:
	"$(MAKE)" -f mak/WINDOWS copy DMD="$(DMD)" HOST_DMD="$(HOST_DMD)" MODEL=$(MODEL) IMPDIR="$(IMPDIR)"

################### C\ASM Targets ############################

errno_c_$(MODEL).obj: src\core\stdc\errno.c
	"$(CC)" -c -Fo$@ $(CFLAGS) src\core\stdc\errno.c

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) win64.mak
	*"$(DMD)" -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

# due to -conf= on the command line, LINKCMD and LIB need to be set in the environment
unittest: $(SRCS) $(DRUNTIME)
	*"$(DMD)" $(UDFLAGS) -version=druntime_unittest $(UTFLAGS) -ofunittest.exe -main $(SRCS) $(DRUNTIME) -debuglib=$(DRUNTIME) -defaultlib=$(DRUNTIME) user32.lib
	.\unittest.exe

################### Win32 COFF support #########################

# default to 32-bit compiler relative to 64-bit compiler, link and lib are architecture agnostic
CC32=$(CC)\..\..\cl

druntime32mscoff:
	"$(MAKE)" -f win64.mak "DMD=$(DMD)" MODEL=32mscoff "CC=$(CC32)" "AR=$(AR)" "VCDIR=$(VCDIR)" "SDKDIR=$(SDKDIR)"

unittest32mscoff:
	"$(MAKE)" -f win64.mak "DMD=$(DMD)" MODEL=32mscoff "CC=$(CC32)" "AR=$(AR)" "VCDIR=$(VCDIR)" "SDKDIR=$(SDKDIR)" unittest

################### tests ######################################

test_uuid:
	"$(MAKE)" -f test\uuid\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) test

test_aa:
	"$(DMD)" -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIME) -run test\aa\src\test_aa.d

test_cpuid:
	"$(MAKE)" -f test\cpuid\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) "CC=$(CC)" test

test_exceptions:
	"$(MAKE)" -f test\exceptions\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) "CC=$(CC)" test

test_hash:
	"$(DMD)" -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIME) -run test\hash\src\test_hash.d

test_stdcpp:
	setmscver.bat
	"$(MAKE)" -f test\stdcpp\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) "CC=$(CC)" test

test_gc:
	"$(MAKE)" -f test\gc\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) "CC=$(CC)" test

custom_gc:
	$(MAKE) -f test\init_fini\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) "CC=$(CC)" test

test_shared:
	$(MAKE) -f test\shared\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) "CC=$(CC)" test

test_mingw: test_shared test_aa test_cpuid test_exceptions test_hash test_gc custom_gc

test_all: test_mingw test_uuid test_stdcpp

################### zip/install/clean ##########################

zip: druntime.zip

druntime.zip: import
	del druntime.zip
	git ls-tree --name-only -r HEAD >MANIFEST.tmp
	zip32 -T -ur druntime @MANIFEST.tmp
	del MANIFEST.tmp

install: druntime.zip
	unzip -o druntime.zip -d \dmd2\src\druntime

clean:
	del $(DRUNTIME) $(OBJS_TO_DELETE)
	rmdir /S /Q $(DOCDIR) $(IMPDIR)

auto-tester-build:
	echo "Windows builds have been disabled on auto-tester"

auto-tester-test:
	echo "Windows builds have been disabled on auto-tester"
