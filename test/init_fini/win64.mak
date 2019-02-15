# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib

test: custom_gc

custom_gc:
	$(DMD) -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) test\init_fini\src\custom_gc.d
	custom_gc.exe
	del custom_gc.exe custom_gc.obj

