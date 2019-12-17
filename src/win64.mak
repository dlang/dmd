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
OBJ_MSVC=$G/strtold.obj $G/longdouble.obj
DEPENDENCIES=vcbuild\msvc-lib.exe $G

MAKE_WIN32=$(MAKE) -f win32.mak MAKE="$(MAKE)" BUILD=$(BUILD) MODEL=$(MODEL) HOST_DC=$(HOST_DC) GEN="$(GEN)" G="$G" OBJ_MSVC="$(OBJ_MSVC)" LIB=vcbuild\msvc-lib

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
scp : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
dmd : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
debdmd : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
reldmd : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
detab : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
tolf : $(DEPENDENCIES)
	$(MAKE_WIN32) $@

$G:
	if not exist "$G" mkdir $G
