# Proxy Makefile for backwards compatibility after move to /compiler/src

############################### Configuration ################################

OS=windows
BUILD=release
MODEL=64
HOST_DC=dmd
MAKE=make
GEN=..\..\generated
G=$(GEN)\$(OS)\$(BUILD)\$(MODEL)

MAKE_WIN32=$(MAKE) -f win64.mak \
	"OS=$(OS)" \
	"BUILD=$(BUILD)" \
	"MODEL=$(MODEL)" \
	"HOST_DMD=$(HOST_DMD)" \
	"HOST_DC=$(HOST_DC)" \
	"MAKE=$(MAKE)" \
	"VERBOSE=$(VERBOSE)" \
	"ENABLE_RELEASE=$(ENABLE_RELEASE)" \
	"ENABLE_DEBUG=$(ENABLE_DEBUG)" \
	"ENABLE_ASSERTS=$(ENABLE_ASSERTS)" \
	"ENABLE_LTO=$(ENABLE_LTO)" \
	"ENABLE_UNITTEST=$(ENABLE_UNITTEST)" \
	"ENABLE_PROFILE=$(ENABLE_PROFILE)" \
	"ENABLE_COVERAGE=$(ENABLE_COVERAGE)" \
	"DFLAGS=$(DFLAGS)" \
	"GEN=$(GEN)" \
	"G=$G"

################################## Targets ###################################

defaulttarget :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
release :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
trace :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
clean :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
install :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
install-clean :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
zip :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
dmd :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
debdmd :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
reldmd :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
reldmd-asserts :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
unittest :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
detab :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
tolf :
	cd ..\compiler\src
	$(MAKE_WIN32) $@
	cd ..\..\src
