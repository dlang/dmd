# SHARED (from druntime/Makefile) is `1` for platforms supporting a shared druntime library, otherwise empty
LINK_SHARED:=$(SHARED)

include ../common.mak # affected by LINK_SHARED!

ifneq (,$(LINK_SHARED))
    # TODO: enable tests on Windows
    ifeq (windows,$(OS))
        TESTS:=link linkD linkDR loadDR
    else
        TESTS:=link load linkD linkDR loadDR host finalize dynamiccast \
               link_linkdep load_linkdep link_loaddep load_loaddep load_13414
    endif
endif
# there are extra tests for Windows, not requiring a druntime DLL
ifeq (windows,$(OS))
    TESTS+=loadlibwin dllrefcount dllgc dynamiccast
endif

DOTIMPLIB:=$(if $(findstring $(OS),windows),.lib,$(DOTDLL))

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

ifeq (windows,$(OS)) # extra tests on Windows

ifeq ($(SHARED),1)
# dmd -shared does not (yet) imply -visibility=public
$(ROOT)/%$(DOTDLL): DFLAGS += -visibility=public

DFLAGS+=-version=SharedRuntime
PATH:=$(dir $(DRUNTIMESO));$(PATH)
endif

$(ROOT)/dllrefcount$(DOTEXE): $(SRC)/dllrefcount.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

$(ROOT)/loadlibwin$(DOTEXE): $(SRC)/loadlibwin.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

$(ROOT)/dllgc$(DOTEXE): $(SRC)/dllgc.d
	$(QUIET)$(DMD) $(DFLAGS) -version=DLL -shared -of$(ROOT)/dllgc$(DOTDLL) $<
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

endif # Windows

$(ROOT)/loadDR.done $(ROOT)/host.done: RUN_ARGS:=$(DRUNTIMESO:.lib=.dll)

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

$(ROOT)/link$(DOTEXE): $(SRC)/link.d $(ROOT)/lib$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< -L$(ROOT)/lib$(DOTIMPLIB)

$(ROOT)/link_linkdep$(DOTEXE): $(SRC)/link_linkdep.d $(ROOT)/lib$(DOTDLL) $(ROOT)/liblinkdep$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKFLAGS) -L$(ROOT)/liblinkdep$(DOTIMPLIB) -L$(ROOT)/lib$(DOTIMPLIB)

$(ROOT)/load_linkdep$(DOTEXE): $(SRC)/load_linkdep.d $(ROOT)/lib$(DOTDLL) $(ROOT)/liblinkdep$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKFLAGS) $(LINKDL)

$(ROOT)/link_loaddep$(DOTEXE): $(SRC)/link_loaddep.d $(ROOT)/lib$(DOTDLL) $(ROOT)/libloaddep$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKFLAGS) -L$(ROOT)/libloaddep$(DOTIMPLIB)

$(ROOT)/load_loaddep$(DOTEXE): $(SRC)/load_loaddep.d $(ROOT)/lib$(DOTDLL) $(ROOT)/libloaddep$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKFLAGS) $(LINKDL)

$(ROOT)/load$(DOTEXE) $(ROOT)/finalize$(DOTEXE): $(ROOT)/%$(DOTEXE): $(SRC)/%.d $(ROOT)/lib$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKDL)

$(ROOT)/load_13414$(DOTEXE): $(ROOT)/%$(DOTEXE): $(SRC)/%.d $(ROOT)/lib_13414$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKDL)

$(ROOT)/dynamiccast$(DOTEXE): $(SRC)/dynamiccast.d $(ROOT)/dynamiccast$(DOTDLL) $(if $(LINK_SHARED),$(DRUNTIMESO),$(DRUNTIME))
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $(SRC)/dynamiccast.d $(LINKDL)

$(ROOT)/dynamiccast$(DOTDLL): $(SRC)/dynamiccast.d  $(if $(LINK_SHARED),$(DRUNTIMESO),$(DRUNTIME))
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< -version=DLL -shared $(LINKDL)

ifeq (windows,$(OS))
    CC:=cl
    CC_OUTFLAG:=/Fe
    # we additionally specify the .obj output path (/Fo) to prevent collisions
    CC_EXTRAS:=
else
    CC_OUTFLAG:=-o
    CC_EXTRAS:=$(LDL) -pthread
endif

$(ROOT)/linkD$(DOTEXE): $(SRC)/linkD.c $(ROOT)/lib$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(CC) $(CFLAGS) $(CC_OUTFLAG)$@ $(if $(findstring $(OS),windows),/Fo$@.obj,) $< $(ROOT)/lib$(DOTIMPLIB) $(CC_EXTRAS)

$(ROOT)/linkDR$(DOTEXE): $(SRC)/linkDR.c $(ROOT)/lib$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(CC) $(CFLAGS) $(CC_OUTFLAG)$@ $(if $(findstring $(OS),windows),/Fo$@.obj,) $< $(DRUNTIME_IMPLIB) $(CC_EXTRAS)

$(ROOT)/loadDR$(DOTEXE): $(SRC)/loadDR.c $(ROOT)/lib$(DOTDLL) $(DRUNTIMESO)
	$(QUIET)$(CC) $(CFLAGS) $(CC_OUTFLAG)$@ $(if $(findstring $(OS),windows),/Fo$@.obj,) $< $(CC_EXTRAS)

$(ROOT)/host$(DOTEXE): $(SRC)/host.c $(ROOT)/plugin1$(DOTDLL) $(ROOT)/plugin2$(DOTDLL)
	$(QUIET)$(CC) $(CFLAGS) $(CC_OUTFLAG)$@ $(if $(findstring $(OS),windows),/Fo$@.obj,) $< $(CC_EXTRAS)

$(ROOT)/liblinkdep$(DOTDLL): $(ROOT)/lib$(DOTDLL)
$(ROOT)/liblinkdep$(DOTDLL): DFLAGS+=-L$(ROOT)/lib$(DOTIMPLIB)

$(ROOT)/plugin1$(DOTDLL) $(ROOT)/plugin2$(DOTDLL): $(SRC)/plugin.d $(DRUNTIMESO)
	$(QUIET)$(DMD) -shared $(DFLAGS) -of$@ $<

$(ROOT)/%$(DOTDLL): $(SRC)/%.d $(DRUNTIMESO)
	$(QUIET)$(DMD) -shared $(DFLAGS) -of$@ $< $(LINKDL)

clean:
	rm -rf $(GENERATED)
