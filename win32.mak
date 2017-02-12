MAKE=make

auto-tester-build:
	cd ../druntime
	git fetch https://github.com/rainers/druntime.git data_ptrref
	git merge FETCH_HEAD
	cd ../dmd
	cd src
	$(MAKE) -f win32.mak auto-tester-build
	cd ..

auto-tester-test:
	cd test
	$(MAKE)
	cd ..

