# set from top makefile
OS:=
MODEL:=
DMD:=
DRUNTIME:=
DRUNTIMESO:=
QUIET:=
LINKDL:= # -L-ldl
LDL:=$(subst -L,,$(LINKDL)) # -ldl

SRC:=src
ROOT:=./obj/$(OS)/$(MODEL)
TESTS:=link load linkD linkDR loadDR host finalize
TESTS+=link_linkdep load_linkdep link_loaddep load_loaddep load_13414

ifneq (default,$(MODEL))
	MODEL_FLAG:=-m$(MODEL)
endif
CFLAGS:=$(MODEL_FLAG) -Wall
DFLAGS:=$(MODEL_FLAG) -w -I../../src -I../../import -I$(SRC) -L$(DRUNTIMESO) -defaultlib= -debuglib=

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/loadDR.done: RUN_ARGS:=$(DRUNTIMESO)

$(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	$(QUIET)$(ROOT)/$* $(RUN_ARGS)
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
	$(QUIET)$(CC) $(CFLAGS) -o $@ $< $(ROOT)/lib.so $(LDL)

$(ROOT)/linkDR: $(SRC)/linkDR.c $(ROOT)/lib.so $(DRUNTIMESO)
	$(QUIET)$(CC) $(CFLAGS) -o $@ $< $(DRUNTIMESO) $(LDL)

$(ROOT)/loadDR: $(SRC)/loadDR.c $(ROOT)/lib.so $(DRUNTIMESO)
	$(QUIET)$(CC) $(CFLAGS) -o $@ $< $(LDL)

$(ROOT)/host: $(SRC)/host.c $(ROOT)/plugin1.so $(ROOT)/plugin2.so
	$(QUIET)$(CC) $(CFLAGS) -o $@ $< $(LDL)

$(ROOT)/liblinkdep.so: $(ROOT)/lib.so
$(ROOT)/liblinkdep.so: DFLAGS+=-L$(ROOT)/lib.so

$(ROOT)/plugin1.so $(ROOT)/plugin2.so: $(SRC)/plugin.d $(DRUNTIMESO)
	$(QUIET)$(DMD) -fPIC -shared $(DFLAGS) -of$@ $<

$(ROOT)/%.so: $(SRC)/%.d $(DRUNTIMESO)
	$(QUIET)$(DMD) -fPIC -shared $(DFLAGS) -of$@ $< $(LINKDL)

clean:
	rm -rf obj
