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
NORMAL_TESTS:=$(addprefix $(ROOT)/,$(addsuffix .done,basic))
MERGE_TESTS:=$(addprefix $(ROOT)/,$(addsuffix .done,merge merge_false))

DIFF:=diff

ifneq (default,$(MODEL))
	MODEL_FLAG:=-m$(MODEL)
endif
CFLAGS:=$(MODEL_FLAG) -Wall
DFLAGS:=$(MODEL_FLAG) -w -I../../src -I../../import -I$(SRC) -L$(DRUNTIME) -defaultlib= -debuglib= -cov

.PHONY: all clean
all: $(NORMAL_TESTS) $(MERGE_TESTS)

$(NORMAL_TESTS): $(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	@rm -f src-$*.lst
	$(QUIET)$(ROOT)/$* $(RUN_ARGS)
	$(QUIET)$(DIFF) src-$*.lst.exp src-$*.lst
	@touch $@

$(MERGE_TESTS): $(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	@rm -f src-$*.lst
	$(QUIET)$(ROOT)/$* $(RUN_ARGS)
	$(QUIET)$(ROOT)/$* $(RUN_ARGS)
	$(QUIET)$(DIFF) src-$*.lst.exp src-$*.lst
	@touch $@

$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$(ROOT)/$* $<

clean:
	rm -rf obj *.lst
