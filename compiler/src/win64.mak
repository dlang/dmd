# DEPRECATED - use src\build.d
#_ win64.mak
#
# Supports same targets as win32.mak.

############################### Configuration ################################

MAKE=make
HOST_DC=dmd
MODEL=64
BUILD=release
OS=windows

################################### Rules ####################################

.d.exe:
	$(HOST_DC) -g -of$@ $<

D=dmd
GEN = ..\generated
G = $(GEN)\$(OS)\$(BUILD)\$(MODEL)
DEPENDENCIES=vcbuild\msvc-lib.exe $G

MAKE_WIN32=$(MAKE) -f win32.mak "OS=$(OS)" "BUILD=$(BUILD)" "MODEL=$(MODEL)" "HOST_DMD=$(HOST_DMD)" "HOST_DC=$(HOST_DC)" "MAKE=$(MAKE)" "VERBOSE=$(VERBOSE)" "ENABLE_RELEASE=$(ENABLE_RELEASE)" "ENABLE_DEBUG=$(ENABLE_DEBUG)" "ENABLE_ASSERTS=$(ENABLE_ASSERTS)" "ENABLE_LTO=$(ENABLE_LTO)" "ENABLE_UNITTEST=$(ENABLE_UNITTEST)" "ENABLE_PROFILE=$(ENABLE_PROFILE)" "ENABLE_COVERAGE=$(ENABLE_COVERAGE)" "DFLAGS=$(DFLAGS)" "GEN=$(GEN)" "G=$G" "LIB=vcbuild\msvc-lib"

################################## Targets ###################################

defaulttarget : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
release : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
trace : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
clean :
	del /s /q $(DEPENDENCIES) dmd.pdb
	$(MAKE_WIN32) $@
install : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
install-clean : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
zip : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
dmd : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
debdmd : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
reldmd : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
reldmd-asserts : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
unittest : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
detab : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
tolf : $(DEPENDENCIES)
	$(MAKE_WIN32) $@

$G:
	if not exist "$G" mkdir $G
