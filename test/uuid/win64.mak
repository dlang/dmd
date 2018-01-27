# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib

test:
	$(DMD) -m$(MODEL) -conf= -I..\..\src -defaultlib=$(DRUNTIMELIB) test.d uuid.lib
	del test.exe test.obj

