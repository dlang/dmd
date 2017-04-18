MAKE=make

auto-tester-build:
	cd src
	$(MAKE) -f win32.mak auto-tester-build
	cd ..

auto-tester-test: auto-tester-samples
	cd test
	$(MAKE)
	cd ..

# hard coding gmake here as the auto-tester does 
#  some patches only to the lines with $(MAKE) above
auto-tester-samples:
	cd samples
	gmake -f win32.mak DMD=..\src\dmd.exe "DFLAGS=-I..\..\druntime\import -I..\..\phobos" LIB=..\..\phobos
	cd ..

