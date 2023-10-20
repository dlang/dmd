MAKE=make

defaulttarget:
	cd compiler\src
	$(MAKE) -f win32.mak
	cd ..\..

auto-tester-build:
	echo "Auto-Tester has been disabled"

auto-tester-test:
	echo "Auto-Tester has been disabled"
