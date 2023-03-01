# Makefile to build D runtime library lib\druntime64.lib for 64 bit Windows and
# lib\druntime32mscoff.lib for 32 bit Windows. Both are for use with the MSVC toolchain.

# Determines whether lib\druntime32mscoff.lib is built or lib\druntime64.lib
# Set to `32mscoff` for a 32-bit build, `64` for 64-bit build.
MODEL=64

# Assume MSVC cl.exe in PATH is set up for the target MODEL.
# Otherwise set it explicitly, e.g., to `C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.29.30133\bin\Hostx86\x86\cl.exe`.
CC=cl

DMD_DIR=..\compiler

BUILD=release
OS=windows

# The D compiler used to build things
DMD=$(DMD_DIR)\..\generated\$(OS)\$(BUILD)\$(MODEL)\dmd

DOCDIR=doc
IMPDIR=import

# Make program to use. Designed to be run with make.exe which can be obtained from
# https://downloads.dlang.org/other/dm857c.zip
MAKE=make

HOST_DMD=dmd

DFLAGS=-m$(MODEL) -conf= -O -release -preview=dip1000 -preview=fieldwise -preview=dtorfields -inline -w -Isrc -Iimport
UDFLAGS=-m$(MODEL) -conf= -O -release -preview=dip1000 -preview=fieldwise -w -version=_MSC_VER_$(_MSC_VER) -Isrc -Iimport
DDOCFLAGS=-conf= -c -w -o- -Isrc -Iimport -version=CoreDdoc

UTFLAGS=-version=CoreUnittest -unittest -checkaction=context

DRUNTIME_BASE=druntime$(MODEL)
DRUNTIME=lib\$(DRUNTIME_BASE).lib

DOCFMT=

target: copydir copy $(DRUNTIME)

$(mak\COPY)
$(mak\DOCS)
$(mak\SRCS)

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)

OBJS= errno_c_$(MODEL).obj
OBJS_TO_DELETE= errno_c_$(MODEL).obj

######################## Header file copy ##############################

import: copy

copydir:
	"$(MAKE)" -f mak/WINDOWS copydir DMD="$(DMD)" HOST_DMD="$(HOST_DMD)" MODEL=$(MODEL) IMPDIR="$(IMPDIR)"

copy:
	"$(MAKE)" -f mak/WINDOWS copy DMD="$(DMD)" HOST_DMD="$(HOST_DMD)" MODEL=$(MODEL) IMPDIR="$(IMPDIR)"

################### C\ASM Targets ############################

# Although dmd is compiling the .c files, the preprocessor used is cl.exe. The INCLUDE
# environment variable needs to be set with the path to the VC system include files.

errno_c_$(MODEL).obj: src\core\stdc\errno.c
	$(DMD) -c -of=$@ $(DFLAGS) -P=-I. src\core\stdc\errno.c

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) win64.mak
	*"$(DMD)" -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

# due to -conf= on the command line, LINKCMD and LIB need to be set in the environment
unittest: $(SRCS) $(DRUNTIME)
	*"$(DMD)" $(UDFLAGS) -version=druntime_unittest $(UTFLAGS) -ofunittest.exe -main $(SRCS) $(DRUNTIME) -debuglib=$(DRUNTIME) -defaultlib=$(DRUNTIME) user32.lib
	.\unittest.exe

################### tests ######################################

test_uuid:
	"$(MAKE)" -f test\uuid\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) DRUNTIMELIB=$(DRUNTIME) test

test_aa:
	"$(DMD)" -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIME) -run test\aa\src\test_aa.d

test_allocations:
	"$(MAKE)" -f test\allocations\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) DRUNTIMELIB=$(DRUNTIME) test

test_betterc:
	"$(MAKE)" -f test\betterc\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) DRUNTIMELIB=$(DRUNTIME) test

test_betterc_mingw:
	"$(MAKE)" -f test\betterc\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) DRUNTIMELIB=$(DRUNTIME) MINGW=_mingw test

test_cpuid:
	"$(MAKE)" -f test\cpuid\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) DRUNTIMELIB=$(DRUNTIME) test

test_exceptions:
	"$(MAKE)" -f test\exceptions\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) DRUNTIMELIB=$(DRUNTIME) test

test_hash:
	"$(DMD)" -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIME) -run test\hash\src\test_hash.d

test_stdcpp:
	setmscver.bat
	"$(MAKE)" -f test\stdcpp\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) DRUNTIMELIB=$(DRUNTIME) test

test_gc:
	"$(MAKE)" -f test\gc\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) DRUNTIMELIB=$(DRUNTIME) test

custom_gc:
	$(MAKE) -f test\init_fini\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) DRUNTIMELIB=$(DRUNTIME) test

test_shared:
	$(MAKE) -f test\shared\win64.mak "DMD=$(DMD)" MODEL=$(MODEL) DRUNTIMELIB=$(DRUNTIME) test

test_common: test_shared test_aa test_allocations test_cpuid test_exceptions test_hash test_gc custom_gc

test_mingw: test_common test_betterc_mingw

test_all: test_common test_betterc test_uuid test_stdcpp

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
