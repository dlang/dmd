# set from top makefile
OS:=
MODEL:=
DMD:=
DRUNTIME:=
DRUNTIMESO:=
QUIET:=

SRC:=src
ROOT:=obj/$(OS)/$(MODEL)
TESTS:=thread_join

ifneq (default,$(MODEL))
	MODEL_FLAG:=-m$(MODEL)
endif
CFLAGS:=$(MODEL_FLAG) -Wall
DFLAGS:=$(MODEL_FLAG) -w -I../../src -I../../import -I$(SRC) -L$(DRUNTIME) -defaultlib= -debuglib=

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	$(QUIET)./$(ROOT)/$* $(RUN_ARGS)
	@touch $@

$(ROOT)/thread_join: $(SRC)/thread_join.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

clean:
	rm -rf obj
