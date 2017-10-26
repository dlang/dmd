# To be able to use this Makefile Visual Studio must be installed.
# If the VC version is not 10.0, then the environment variable VCINSTALLDIR must be set
# to the directory where it is installed (e.g. C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\).
# The corresponding vcvarsall.bat must also be called (e.g. call C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat amd64)

MAKE=make

all:
	cd src
	$(MAKE) -f win64.mak
