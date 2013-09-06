# set from top makefile
OS:=
MODEL:=
DMD:=
DRUNTIMESO:=
QUIET:=

SRC:=src
ROOT:=obj/$(OS)/$(MODEL)
TESTS:=link load

ifneq (default,$(MODEL))
	MODEL_FLAG:=-m$(MODEL)
endif
DFLAGS:=$(MODEL_FLAG) -w -I../../src -I../../import -I$(SRC) -L$(DRUNTIMESO) -defaultlib= -debuglib=

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	$(QUIET)./$(ROOT)/$*
	@touch $@

$(ROOT)/link: $(SRC)/link.d $(ROOT)/lib.so $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< -L$(ROOT)/lib.so

$(ROOT)/load: $(SRC)/load.d $(ROOT)/lib.so $(DRUNTIMESO)
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< -L-ldl

$(ROOT)/lib.so: $(SRC)/lib.d $(DRUNTIMESO)
	$(QUIET)$(DMD) -fPIC -shared $(DFLAGS) -of$@ $<

clean:
	rm -rf obj
