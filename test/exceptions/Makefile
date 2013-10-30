# set from top makefile
OS:=
MODEL:=
DMD:=
DRUNTIME:=
DRUNTIMESO:=
QUIET:=

SRC:=src
ROOT:=obj/$(OS)/$(MODEL)
TESTS:=stderr_msg

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

$(ROOT)/stderr_msg.done: $(ROOT)/stderr_msg
	@echo Testing stderr_msg
	$(QUIET)./$(ROOT)/stderr_msg $(RUN_ARGS) 2>&1 1>/dev/null | grep -qF "stderr_msg msg"
	@touch $@

$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

clean:
	rm -rf obj
