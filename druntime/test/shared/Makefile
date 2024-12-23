override LINK_SHARED := $(SHARED)

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

include ../common.mak

abs_root := $(abspath $(ROOT))
# on posix we link directly to the .so
# on windows you have to link the .lib which references the .dll
for_linking := $(if $(filter windows,$(OS)),.lib,$(DOTDLL))

ifeq (windows,$(OS)) # extra tests on Windows

ifeq ($(SHARED),1)
# dmd -shared does not (yet) imply -visibility=public
$(ROOT)/%$(DOTDLL): private extra_dflags += -visibility=public

extra_dflags += -version=SharedRuntime
PATH := $(dir $(DRUNTIMESO));$(PATH)
endif

$(ROOT)/dllgc.done: $(ROOT)/dllgc$(DOTDLL)
$(ROOT)/dllgc$(DOTDLL): extra_dflags += -version=DLL
endif # Windows

$(ROOT)/dynamiccast.done: $(ROOT)/%.done: $(ROOT)/%$(DOTEXE) $(ROOT)/%$(DOTDLL)
	@echo Testing $*
	$(RM) $(ROOT)/dynamiccast_end{bar,main}
	$(TIMELIMIT)$<
	test -f $(ROOT)/dynamiccast_endbar
	test -f $(ROOT)/dynamiccast_endmain
	@touch $@
$(ROOT)/dynamiccast$(DOTEXE): private extra_ldlibs.d += $(LINKDL)
$(ROOT)/dynamiccast$(DOTDLL): private extra_dflags += -version=DLL

# Avoid a race condition that I sometimes hit with make -j8.
# Maybe temporary file collisions when invoking the linker?
$(OBJDIR)/dynamiccast$(DOTEXE): $(OBJDIR)/dynamiccast$(DOTDLL)

$(OBJDIR)/link$(DOTEXE): $(OBJDIR)/lib$(for_linking) lib.d
$(OBJDIR)/link$(DOTEXE): private extra_ldlibs.d += $(abs_root)/lib$(for_linking)

$(ROOT)/liblinkdep$(DOTDLL): $(OBJDIR)/lib$(for_linking) lib.d
$(ROOT)/liblinkdep$(DOTDLL): private extra_ldlibs.d += $(abs_root)/lib$(for_linking)

$(ROOT)/libloaddep$(DOTDLL): private extra_ldlibs.d += $(LINKDL)

$(ROOT)/link_linkdep$(DOTEXE): $(ROOT)/liblinkdep$(for_linking) liblinkdep.d
$(ROOT)/link_linkdep$(DOTEXE): private extra_ldlibs.d += $(abs_root)/liblinkdep$(for_linking)

# dlopens lib.so through libloaddep
$(ROOT)/link_loaddep.done: $(ROOT)/lib$(DOTDLL)
$(ROOT)/link_loaddep$(DOTEXE): $(ROOT)/libloaddep$(for_linking) libloaddep.d utils.di
$(ROOT)/link_loaddep$(DOTEXE): private extra_ldlibs.d += $(abs_root)/libloaddep$(for_linking)

# dlopens liblinkdep.so
$(ROOT)/load_linkdep.done: $(ROOT)/liblinkdep$(DOTDLL)
$(ROOT)/load_linkdep$(DOTEXE): utils.di
$(ROOT)/load_linkdep$(DOTEXE): private extra_ldlibs.d += $(LINKDL)

# dlopens libloaddep.so and runs code that will dlopen lib.so
$(ROOT)/load_loaddep.done: $(ROOT)/lib$(DOTDLL) $(ROOT)/libloaddep$(DOTDLL)
$(ROOT)/load_loaddep$(DOTEXE): utils.di
$(ROOT)/load_loaddep$(DOTEXE): private extra_ldlibs.d += $(LINKDL)

$(ROOT)/load.done: $(ROOT)/lib$(DOTDLL)
$(ROOT)/load$(DOTEXE): utils.di
$(ROOT)/load$(DOTEXE): private extra_ldlibs.d += $(LINKDL)

$(ROOT)/finalize.done: $(ROOT)/lib$(DOTDLL)
$(ROOT)/finalize$(DOTEXE): utils.di
$(ROOT)/finalize$(DOTEXE): private extra_ldlibs.d += $(LINKDL)

$(ROOT)/load_13414.done: $(ROOT)/lib_13414$(DOTDLL)
$(ROOT)/load_13414$(DOTEXE): utils.di
$(ROOT)/load_13414$(DOTEXE): private extra_ldlibs.d += $(LINKDL)

ifeq (windows,$(OS))
    CC := cl
    OUTPUT_FLAG := /Fe
    # we additionally specify the .obj output path (/Fo) to prevent collisions
    extra_cflags += /Fo$(OBJDIR)
endif

# $(LINKDL) == -L-ldl => $(ldl) == -ldl
ldl := $(LINKDL:-L%=%)

$(ROOT)/linkD$(DOTEXE): $(ROOT)/lib$(for_linking)
$(ROOT)/linkD$(DOTEXE): private extra_ldlibs += $(abs_root)/lib$(for_linking)

$(ROOT)/linkDR.done: $(ROOT)/lib$(DOTDLL)
$(ROOT)/linkDR$(DOTEXE): $(DRUNTIME_DEP) utils.h
$(ROOT)/linkDR$(DOTEXE): private extra_ldlibs += $(ldl) $(druntime_for_linking)

$(ROOT)/loadDR.done: $(ROOT)/lib$(DOTDLL) $(DRUNTIMESO)
$(ROOT)/loadDR.done: private run_args = $(DRUNTIMESO)
$(ROOT)/loadDR$(DOTEXE): utils.h
$(ROOT)/loadDR$(DOTEXE): private extra_ldlibs += $(ldl)

$(ROOT)/host.done: $(DRUNTIMESO) $(ROOT)/plugin1$(DOTDLL) $(ROOT)/plugin2$(DOTDLL)
$(ROOT)/host.done: private run_args = $(DRUNTIMESO)
$(ROOT)/host$(DOTEXE): utils.h
$(ROOT)/host$(DOTEXE): private extra_ldlibs += $(ldl)

$(ROOT)/plugin1$(DOTDLL) $(ROOT)/plugin2$(DOTDLL): $(ROOT)/plugin$(DOTDLL)
	cp $< $@

########## default rule for building a shared library ##########

$(ROOT)/%$(DOTDLL): %.d $(DMD_DEP) $(DRUNTIME_DEP)
	$(LINK.d) -shared $< $(extra_ldlibs.d) $(LDLIBS.d) $(OUTPUT_OPTION.d)

$(ROOT)/%$(for_linking): $(ROOT)/%$(DOTDLL) ;
