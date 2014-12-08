# set from top makefile
OS:=
MODEL:=
DMD:=
DRUNTIME:=
DRUNTIMESO:=
QUIET:=
LINKDL:=

SRC:=src
ROOT:=./obj/$(OS)/$(MODEL)
TESTS:=stderr_msg unittest_assert

ifneq (default,$(MODEL))
	MODEL_FLAG:=-m$(MODEL)
endif
CFLAGS:=$(MODEL_FLAG) -Wall
DFLAGS:=$(MODEL_FLAG) -w -I../../src -I../../import -I$(SRC) -L$(DRUNTIME) -defaultlib= -debuglib=

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	$(QUIET)$(ROOT)/$* $(RUN_ARGS)
	@touch $@

$(ROOT)/stderr_msg.done: $(ROOT)/stderr_msg
	@echo Testing stderr_msg
	$(QUIET)./$(ROOT)/stderr_msg $(RUN_ARGS) 2>&1 1>/dev/null | grep -qF "stderr_msg msg"
	@touch $@

$(ROOT)/unittest_assert.done: $(ROOT)/unittest_assert
	@echo Testing unittest_assert
	$(QUIET)./$(ROOT)/unittest_assert $(RUN_ARGS) 2>&1 1>/dev/null | grep -qF "unittest_assert msg"
	@touch $@

$(ROOT)/unittest_assert: DFLAGS+=-unittest
$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

clean:
	rm -rf obj
