# Makefile to build D runtime library lib\druntime64.lib for 64 bit Windows and
# lib\druntime32mscoff.lib for 32 bit Windows. Both are for use with the MSVC toolchain.

# Determines whether lib\druntime32mscoff.lib is built or lib\druntime64.lib
# Set to `32mscoff` for a 32-bit build, `64` for 64-bit build.
MODEL=64

DMD_DIR=..\compiler

BUILD=release
OS=windows

# The D compiler used to build things
DMD=$(DMD_DIR)\..\generated\$(OS)\$(BUILD)\$(MODEL)\dmd

# Make program to use. Designed to be run with make.exe which can be obtained from
# https://downloads.dlang.org/other/dm857c.zip
MAKE=make

DRUNTIME=$(DMD_DIR)\..\generated\$(OS)\$(BUILD)\$(MODEL)\druntime.lib

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
