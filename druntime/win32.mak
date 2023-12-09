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

DRUNTIME=$(DMD_DIR)\..\generated\$(OS)\$(BUILD)\32omf\druntime.lib

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
