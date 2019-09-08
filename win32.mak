MAKE=make

defaulttarget:
	cd src
	$(MAKE) -f win32.mak
	cd ..

auto-tester-build:
	cd src
	$(MAKE) -f win32.mak auto-tester-build
	cd ..

auto-tester-test:
	cd test
	gmake -j1 start_all_tests "DMD_TESTSUITE_MAKE_ARGS=-j$(PARALLELISM)"
	cd ..
	cd samples
	gmake -f win32.mak DMD=..\src\dmd.exe MODEL=$(MODEL) "LIB=..\..\phobos;$(LIB)" \
		"DFLAGS=-I..\..\druntime\import -I..\..\phobos -m$(MODEL)"
	cd ..

