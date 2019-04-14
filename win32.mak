MAKE=make
HOST_DMD?=dmd

defaulttarget:
	cd src
	$(HOST_DMD) -run ./src/build.d -v all MODEL=64
	cd ..

auto-tester-build:
	cd src
	$(HOST_DMD) -run ./src/build.d -v all MODEL=64
	cd ..

auto-tester-test:
	cd test
	$(MAKE)
	cd ..
	cd samples
	gmake -f win32.mak DMD=..\src\dmd.exe MODEL=$(MODEL) "LIB=..\..\phobos;$(LIB)" \
		"DFLAGS=-I..\..\druntime\import -I..\..\phobos -m$(MODEL)"
	cd ..

