# Makefile to build D runtime library druntime.lib for Win32 OMF
# MS COFF builds use win64.mak for 32 and 64 bit

# Ignored, only the default value is supported
#MODEL=32omf

DMD_DIR=..\compiler
BUILD=release
OS=windows
DMD=$(DMD_DIR)\..\generated\$(OS)\$(BUILD)\32\dmd

# Used for running MASM assembler on .asm files
CC=dmc

MAKE=make
HOST_DMD=dmd

DOCDIR=doc
IMPDIR=import

# For compiling D and ImportC files
DFLAGS=-m32omf -conf= -O -release -preview=dip1000 -preview=fieldwise -preview=dtorfields -inline -w -Isrc -Iimport
# For unittest build
UDFLAGS=-m32omf -conf= -O -release -preview=dip1000 -preview=fieldwise -w -Isrc -Iimport
# Also for unittest build
UTFLAGS=-version=CoreUnittest -unittest -checkaction=context

CFLAGS=

DRUNTIME_BASE=druntime
DRUNTIME=lib\$(DRUNTIME_BASE).lib

DOCFMT=

target: copydir copy $(DRUNTIME)

$(mak\COPY)
$(mak\DOCS)
$(mak\SRCS)

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for Linux

OBJS= errno_c_32omf.obj src\rt\minit.obj
OBJS_TO_DELETE= errno_c_32omf.obj

######################## Header file copy ##############################

import: copy

copydir:
	"$(MAKE)" -f mak/WINDOWS copydir DMD="$(DMD)" HOST_DMD="$(HOST_DMD)" MODEL=32 IMPDIR="$(IMPDIR)"

copy:
	"$(MAKE)" -f mak/WINDOWS copy DMD="$(DMD)" HOST_DMD="$(HOST_DMD)" MODEL=32 IMPDIR="$(IMPDIR)"

################### Win32 Import Libraries ###################

IMPLIBS= \
	lib\win32\glu32.lib \
	lib\win32\odbc32.lib \
	lib\win32\opengl32.lib \
	lib\win32\rpcrt4.lib \
	lib\win32\shell32.lib \
	lib\win32\version.lib \
	lib\win32\wininet.lib \
	lib\win32\winspool.lib

implibsdir:
	if not exist lib\win32 mkdir lib\win32

implibs: implibsdir $(IMPLIBS)

lib\win32\glu32.lib: def\glu32.def
	implib $@ $**

lib\win32\odbc32.lib: def\odbc32.def
	implib $@ $**

lib\win32\opengl32.lib: def\opengl32.def
	implib $@ $**

lib\win32\rpcrt4.lib: def\rpcrt4.def
	implib $@ $**

lib\win32\shell32.lib: def\shell32.def
	implib $@ $**

lib\win32\version.lib: def\version.def
	implib $@ $**

lib\win32\wininet.lib: def\wininet.def
	implib $@ $**

lib\win32\winspool.lib: def\winspool.def
	implib $@ $**

################### C\ASM Targets ############################

errno_c_32omf.obj: src\core\stdc\errno.c
	$(DMD) -c -of=$@ $(DFLAGS) -v -P=-I. src\core\stdc\errno.c

# only rebuild explicitly
rebuild_minit_obj: src\rt\minit.asm
	$(CC) -c $(CFLAGS) src\rt\minit.asm

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) win32.mak
	*$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

################### Unittests #########################
# Unittest are not run because OPTLINK tends to crash when linking
# unittest.exe. Note that the unittests are still run for -m32mscoff
# and -m64 which are configured in win64.mak

unittest: unittest.obj
	@echo "Unittests cannot be linked on Win32 + OMF due to OPTLINK issues"

# Split compilation into a different step to avoid unnecessary rebuilds
unittest.obj: $(SRCS) win32.mak
	*$(DMD) $(UDFLAGS) $(UTFLAGS) -c -of$@ $(SRCS)

################### tests ######################################

test_aa:
	$(DMD) -m32omf -conf= -Isrc -defaultlib=$(DRUNTIME) -run test\aa\src\test_aa.d

test_allocations:
	"$(MAKE)" -f test\allocations\win64.mak "DMD=$(DMD)" MODEL=32omf "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) "CC=$(CC)" test

test_cpuid:
	"$(MAKE)" -f test\cpuid\win64.mak "DMD=$(DMD)" MODEL=32omf "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) "CC=$(CC)" test

test_exceptions:
	"$(MAKE)" -f test\exceptions\win64.mak "DMD=$(DMD)" MODEL=32omf "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) "CC=$(CC)" test

test_hash:
	$(DMD) -m32omf -conf= -Isrc -defaultlib=$(DRUNTIME) -run test\hash\src\test_hash.d

test_gc:
	"$(MAKE)" -f test\gc\win64.mak "DMD=$(DMD)" MODEL=32omf "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) "CC=$(CC)" test

custom_gc:
	$(MAKE) -f test\init_fini\win64.mak "DMD=$(DMD)" MODEL=32omf "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) "CC=$(CC)" test

test_shared:
	$(MAKE) -f test\shared\win64.mak "DMD=$(DMD)" MODEL=32omf "VCDIR=$(VCDIR)" DRUNTIMELIB=$(DRUNTIME) "CC=$(CC)" test

test_all: test_aa test_allocations test_cpuid test_exceptions test_hash test_gc custom_gc test_shared

################### zip/install/clean ##########################

zip: druntime.zip

druntime.zip:
	del druntime.zip
	git ls-tree --name-only -r HEAD >MANIFEST.tmp
	zip32 -T -ur druntime @MANIFEST.tmp
	del MANIFEST.tmp

install: druntime.zip
	unzip -o druntime.zip -d \dmd2\src\druntime

clean:
	del $(DRUNTIME) $(OBJS_TO_DELETE)
	rmdir /S /Q $(DOCDIR) $(IMPDIR)
