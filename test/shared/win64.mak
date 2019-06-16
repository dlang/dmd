# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib

test: loadlibwin dllrefcount dllgc

dllrefcount:
	$(DMD) -g -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) test\shared\src\dllrefcount.d
	dllrefcount.exe
	del dllrefcount.exe dllrefcount.obj

loadlibwin:
	$(DMD) -g -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) test\shared\src\loadlibwin.d
	loadlibwin.exe
	del loadlibwin.exe loadlibwin.obj

dllgc:
	$(DMD) -g -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -version=DLL -shared -ofdllgc.dll test\shared\src\dllgc.d
	$(DMD) -g -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -ofloaddllgc.exe test\shared\src\dllgc.d
	loaddllgc.exe
	del loaddllgc.exe loaddllgc.obj dllgc.dll dllgc.obj
