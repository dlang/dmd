# To be able to use this Makefile Visual Studio must be installed, and either
# a "Visual Studio Command prompt" use to run make or manually calling
# `vcvarsall.bat amd64` from the command-line beforehand.

MAKE=make

all:
	cd compiler\src
	$(MAKE) -f win64.mak
