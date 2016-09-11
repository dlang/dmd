LINK_SHARED:=1

include ../common.mak

TESTS:=link load linkD linkDR loadDR host finalize
TESTS+=link_linkdep load_linkdep link_loaddep load_loaddep load_13414
TESTS+=link_mod_collision load_mod_collision

EXPORT_DYNAMIC=$(if $(findstring $(OS),linux freebsd),-L--export-dynamic,)
NO_AS_NEEDED=$(if $(findstring $(OS),linux freebsd),-L--no-as-needed,)

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/loadDR.done $(ROOT)/host.done: RUN_ARGS:=$(DRUNTIMESO)

$(ROOT)/%_mod_collision.done: $(ROOT)/%_mod_collision
	@echo Testing $*_mod_collision
	$(QUIET)($(TIMELIMIT)$< $(RUN_ARGS) 2>&1 || true) | grep -qF 'already defined'
	@touch $@

$(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$< $(RUN_ARGS)
	@touch $@

$(ROOT)/link: $(SRC)/link.d $(ROOT)/lib.so $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< -L$(ROOT)/lib.so

$(ROOT)/link_linkdep: $(SRC)/link_linkdep.d $(ROOT)/lib.so $(ROOT)/liblinkdep.so $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKFLAGS) -L$(ROOT)/liblinkdep.so -L$(ROOT)/lib.so

$(ROOT)/load_linkdep: $(SRC)/load_linkdep.d $(ROOT)/lib.so $(ROOT)/liblinkdep.so $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKFLAGS) $(LINKDL)

$(ROOT)/link_loaddep: $(SRC)/link_loaddep.d $(ROOT)/lib.so $(ROOT)/libloaddep.so $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKFLAGS) -L$(ROOT)/libloaddep.so

$(ROOT)/load_loaddep: $(SRC)/load_loaddep.d $(ROOT)/lib.so $(ROOT)/libloaddep.so $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKFLAGS) $(LINKDL)

$(ROOT)/load $(ROOT)/finalize: $(ROOT)/%: $(SRC)/%.d $(ROOT)/lib.so $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKDL)

$(ROOT)/load_13414: $(ROOT)/%: $(SRC)/%.d $(ROOT)/lib_13414.so $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKDL)

$(ROOT)/linkD: $(SRC)/linkD.c $(ROOT)/lib.so $(DRUNTIMESO)
	$(QUIET)$(CC) $(CFLAGS) -o $@ $< $(ROOT)/lib.so $(LDL) -pthread

$(ROOT)/linkDR: $(SRC)/linkDR.c $(ROOT)/lib.so $(DRUNTIMESO)
	$(QUIET)$(CC) $(CFLAGS) -o $@ $< $(DRUNTIMESO) $(LDL) -pthread

$(ROOT)/loadDR: $(SRC)/loadDR.c $(ROOT)/lib.so $(DRUNTIMESO)
	$(QUIET)$(CC) $(CFLAGS) -o $@ $< $(LDL) -pthread

$(ROOT)/host: $(SRC)/host.c $(ROOT)/plugin1.so $(ROOT)/plugin2.so
	$(QUIET)$(CC) $(CFLAGS) -o $@ $< $(LDL) -pthread

$(ROOT)/link_mod_collision: $(ROOT)/%: $(SRC)/%.d $(ROOT)/lib.so $(DRUNTIMESO)
#	use no-as-needed to enforce linking of unused lib.so
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(NO_AS_NEEDED) -L$(ROOT)/lib.so

$(ROOT)/load_mod_collision: $(ROOT)/%: $(SRC)/%.d $(ROOT)/lib.so $(DRUNTIMESO)
#	use export dynamic so that Module in exe can interposes Module in lib.so
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< $(LINKDL) $(EXPORT_DYNAMIC)

$(ROOT)/liblinkdep.so: $(ROOT)/lib.so
$(ROOT)/liblinkdep.so: DFLAGS+=-L$(ROOT)/lib.so

$(ROOT)/plugin1.so $(ROOT)/plugin2.so: $(SRC)/plugin.d $(DRUNTIMESO)
	$(QUIET)$(DMD) -fPIC -shared $(DFLAGS) -of$@ $<

$(ROOT)/%.so: $(SRC)/%.d $(DRUNTIMESO)
	$(QUIET)$(DMD) -fPIC -shared $(DFLAGS) -of$@ $< $(LINKDL)

clean:
	rm -rf $(GENERATED)
