# built from the druntime top-level folder
# to be overwritten by caller
DMD=dmd
MODEL=64
DRUNTIMELIB=druntime64.lib

test: loadlibwin dllrefcount dllgc dynamiccast

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

dynamiccast:
	$(DMD) -g -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -version=DLL -shared -ofdynamiccast.dll test\shared\src\dynamiccast.d
	$(DMD) -g -m$(MODEL) -conf= -Isrc -defaultlib=$(DRUNTIMELIB) -ofdynamiccast.exe test\shared\src\dynamiccast.d
	dynamiccast.exe
	cmd /c "if not exist dynamiccast_endbar exit 1"
	cmd /c "if not exist dynamiccast_endmain exit 1"
	del dynamiccast.exe dynamiccast.dll dynamiccast.obj dynamiccast_endbar dynamiccast_endmain
