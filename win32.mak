MAKE=make

auto-tester-build:
	cd src
	$(MAKE) -f win32.mak auto-tester-build
	cd ..

auto-tester-test:
	cd test
	$(MAKE)
	cd ..

