#_ win64.mak
#
# Supports same targets as win32.mak.

############################### Configuration ################################

MAKE=make
HOST_DC=dmd

################################### Rules ####################################

.d.exe:
	$(HOST_DC) -of$@ $<

OBJ_MSVC=strtold.obj longdouble.obj ldfpu.obj
DEPENDENCIES=vcbuild\msvc-dmc.exe vcbuild\msvc-lib.exe

MAKE_WIN32=$(MAKE) -f win32.mak DMODEL=-m64 HOST_DC=$(HOST_DC) CC=vcbuild\msvc-dmc LIB=vcbuild\msvc-lib

################################## Targets ###################################

defaulttarget : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
release : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
trace : $(DEPENDENCIES)
	$(MAKE_WIN32) $@
clean : $(DEPENDENCIES)
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
