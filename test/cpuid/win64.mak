# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib

test: cpuid

cpuid:
	$(DMD) -g -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) test\cpuid\src\cpuid.d
	cpuid.exe
	del cpuid.exe cpuid.obj
