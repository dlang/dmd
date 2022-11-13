MAKE=make

defaulttarget:
	cd compiler\src
	$(MAKE) -f win32.mak
	cd ..\..

auto-tester-build:
	cd compiler\src
	$(MAKE) -f win32.mak auto-tester-build
	cd ..\..
	cd druntime
	$(MAKE) -f win32.mak auto-tester-build
	cd ..

auto-tester-test:
	cd compiler\test
	$(MAKE)
	cd ..\..
	cd druntime
	$(MAKE) -f win32.mak auto-tester-test
	cd ..
	cd compiler\samples
	gmake -f win32.mak DMD=..\src\dmd.exe MODEL=$(MODEL) "LIB=..\..\phobos;$(LIB)" \
		"DFLAGS=-I..\..\druntime\import -I..\..\phobos -m$(MODEL)"
	cd ..\..
