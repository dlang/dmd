# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib

test:
	$(DMD) -m$(MODEL) -conf= -Iimport -defaultlib=$(DRUNTIMELIB) -g test\exceptions\src\winstack.d
	winstack.exe
	del winstack.*
