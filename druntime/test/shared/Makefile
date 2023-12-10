# druntime DLL not supported on Windows yet
LINK_SHARED:=$(if $(findstring $(OS),windows),,1)

include ../common.mak # affected by LINK_SHARED!

.PHONY: all clean

ifeq (windows,$(OS))

TESTS:=loadlibwin dllrefcount dllgc dynamiccast

all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$< $(RUN_ARGS)
	@touch $@

$(ROOT)/dynamiccast.done: $(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(QUIET)rm -f $(ROOT)/dynamiccast_end{bar,main}
	$(QUIET)$(TIMELIMIT)$< $(RUN_ARGS)
	$(QUIET)test -f $(ROOT)/dynamiccast_endbar
	$(QUIET)test -f $(ROOT)/dynamiccast_endmain
	@touch $@

$(ROOT)/dllrefcount$(DOTEXE): $(SRC)/dllrefcount.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

$(ROOT)/loadlibwin$(DOTEXE): $(SRC)/loadlibwin.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

$(ROOT)/dllgc$(DOTEXE): $(SRC)/dllgc.d
	$(QUIET)$(DMD) $(DFLAGS) -version=DLL -shared -of$(ROOT)/dllgc$(DOTDLL) $<
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

$(ROOT)/dynamiccast$(DOTEXE): $(SRC)/dynamiccast.d
	$(QUIET)$(DMD) $(DFLAGS) -version=DLL -shared -of$(ROOT)/dynamiccast$(DOTDLL) $<
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

else # Posix:

TESTS:=link load linkD linkDR loadDR host finalize dynamiccast
TESTS+=link_linkdep load_linkdep link_loaddep load_loaddep load_13414

EXPORT_DYNAMIC=$(if $(findstring $(OS),linux freebsd dragonflybsd),-L--export-dynamic,)
NO_AS_NEEDED=$(if $(findstring $(OS),linux freebsd dragonflybsd),-L--no-as-needed,)

all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/loadDR.done $(ROOT)/host.done: RUN_ARGS:=$(DRUNTIMESO)

$(ROOT)/dynamiccast.done: CLEANUP:=rm $(ROOT)/dynamiccast_endmain$(DOTEXE) $(ROOT)/dynamiccast_endbar$(DOTEXE)

$(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$< $(RUN_ARGS)
	$(CLEANUP)
	@touch $@

$(ROOT)/link$(DOTEXE): $(SRC)/link.d $(ROOT)/lib$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< -L$(ROOT)/lib$(DOTDLL)

$(ROOT)/link_linkdep$(DOTEXE): $(SRC)/link_linkdep.d $(ROOT)/lib$(DOTDLL) $(ROOT)/liblinkdep$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKFLAGS) -L$(ROOT)/liblinkdep$(DOTDLL) -L$(ROOT)/lib$(DOTDLL)

$(ROOT)/load_linkdep$(DOTEXE): $(SRC)/load_linkdep.d $(ROOT)/lib$(DOTDLL) $(ROOT)/liblinkdep$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKFLAGS) $(LINKDL)

$(ROOT)/link_loaddep$(DOTEXE): $(SRC)/link_loaddep.d $(ROOT)/lib$(DOTDLL) $(ROOT)/libloaddep$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKFLAGS) -L$(ROOT)/libloaddep$(DOTDLL)

$(ROOT)/load_loaddep$(DOTEXE): $(SRC)/load_loaddep.d $(ROOT)/lib$(DOTDLL) $(ROOT)/libloaddep$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKFLAGS) $(LINKDL)

$(ROOT)/load$(DOTEXE) $(ROOT)/finalize$(DOTEXE): $(ROOT)/%$(DOTEXE): $(SRC)/%.d $(ROOT)/lib$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKDL)

$(ROOT)/load_13414$(DOTEXE): $(ROOT)/%$(DOTEXE): $(SRC)/%.d $(ROOT)/lib_13414$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKDL)

$(ROOT)/dynamiccast$(DOTEXE): $(SRC)/dynamiccast.d $(ROOT)/dynamiccast$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $(SRC)/dynamiccast.d $(LINKDL)

$(ROOT)/dynamiccast$(DOTDLL): $(SRC)/dynamiccast.d $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< -version=DLL -fPIC -shared $(LINKDL)

$(ROOT)/linkD$(DOTEXE): $(SRC)/linkD.c $(ROOT)/lib$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(CC) $(CFLAGS) -o $@ $< $(ROOT)/lib$(DOTDLL) $(LDL) -pthread

$(ROOT)/linkDR$(DOTEXE): $(SRC)/linkDR.c $(ROOT)/lib$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(CC) $(CFLAGS) -o $@ $< $(DRUNTIMESO) $(LDL) -pthread

$(ROOT)/loadDR$(DOTEXE): $(SRC)/loadDR.c $(ROOT)/lib$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(CC) $(CFLAGS) -o $@ $< $(LDL) -pthread

$(ROOT)/host$(DOTEXE): $(SRC)/host.c $(ROOT)/plugin1$(DOTDLL) $(ROOT)/plugin2$(DOTDLL)
	$(QUIET)$(CC) $(CFLAGS) -o $@ $< $(LDL) -pthread

$(ROOT)/liblinkdep$(DOTDLL): $(ROOT)/lib$(DOTDLL)
$(ROOT)/liblinkdep$(DOTDLL): DFLAGS+=-L$(ROOT)/lib$(DOTDLL)

$(ROOT)/plugin1$(DOTDLL) $(ROOT)/plugin2$(DOTDLL): $(SRC)/plugin.d $(DRUNTIMESO)
	$(QUIET)$(DMD) -fPIC -shared $(DFLAGS) -of$@ $<

$(ROOT)/%$(DOTDLL): $(SRC)/%.d $(DRUNTIMESO)
	$(QUIET)$(DMD) -fPIC -shared $(DFLAGS) -of$@ $< $(LINKDL)

endif # end Posix

clean:
	rm -rf $(GENERATED)
