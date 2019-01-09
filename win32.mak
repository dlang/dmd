MAKE=make

auto-tester-build:
	cd src
	$(MAKE) -f win32.mak auto-tester-build
	cd ..

# Disable D2 testsuite for DMD.
auto-tester-test:
	@echo "Auto-tester tests disabled"

