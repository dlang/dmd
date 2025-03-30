TESTS := profile profilegc both

include ../common.mak


DIFF:=diff --strip-trailing-cr
GREP:=grep
SED:=sed

ifeq (freebsd,$(OS))
    SHELL=/usr/local/bin/bash
else ifeq (openbsd,$(OS))
    SHELL=/usr/local/bin/bash
else ifeq (netbsd,$(OS))
    SHELL=/usr/pkg/bin/bash
else ifeq (dragonflybsd,$(OS))
    SHELL=/usr/local/bin/bash
else ifneq (windows,$(OS)) # already using a bash shell on Windows via common.mak
    SHELL=/bin/bash
endif

$(ROOT)/profile.done: $(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	@rm -f $(ROOT)/mytrace.log $(ROOT)/mytrace.def
	$(TIMELIMIT)$(ROOT)/$* $(ROOT)/mytrace.log $(ROOT)/mytrace.def
	$(GREP) -q '1 .*_Dmain' $(ROOT)/mytrace.log
	$(GREP) -q '1000 .*uint profile.foo(uint)' $(ROOT)/mytrace.log
	cat $(ROOT)/mytrace.def
	sort $(ROOT)/mytrace.def -o $(ROOT)/mytrace.def
	(sort mytrace.def.exp | $(DIFF) - $(ROOT)/mytrace.def) || (sort mytrace.releaseopt.def.exp | $(DIFF) - $(ROOT)/mytrace.def)
	@touch $@
$(ROOT)/profile$(DOTEXE): extra_dflags += -profile

$(ROOT)/profilegc.done: $(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	@rm -f $(ROOT)/myprofilegc.log
	$(TIMELIMIT)$(ROOT)/$* $(ROOT)/myprofilegc.log
	$(DIFF) \
		<($(GREP) -vF 'core.' myprofilegc.log.$(OS).$(shell echo $(MODEL) | cut -c 1-2).exp) \
		<($(GREP) -vF 'core.' $(ROOT)/myprofilegc.log)
	@touch $@
$(ROOT)/profilegc$(DOTEXE): extra_dflags += -profile=gc

$(ROOT)/both.done: $(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	@rm -f $(ROOT)/both.log $(ROOT)/both.def $(ROOT)/bothgc.log
	$(TIMELIMIT)$(ROOT)/$* $(ROOT)/both.log $(ROOT)/both.def $(ROOT)/bothgc.log
	$(GREP) -q '1 .*_Dmain' $(ROOT)/both.log
	$(GREP) -q '1000 .*both.Num\* both.foo(uint)' $(ROOT)/both.log
	cat $(ROOT)/both.def
	sort $(ROOT)/both.def -o $(ROOT)/both.def
	(sort bothnew.def.exp | $(DIFF) - $(ROOT)/both.def)
ifeq (windows,$(OS))
	$(DIFF) \
		<($(GREP) -vF 'core.' bothgc.log.exp) \
		<($(GREP) -vF 'core.' $(ROOT)/bothgc.log | $(SED) 's: src\\\\: src/:g')
else
	$(DIFF) \
		<($(GREP) -vF 'core.' bothgc.log.exp) \
		<($(GREP) -vF 'core.' $(ROOT)/bothgc.log)
endif
	@touch $@
$(ROOT)/both$(DOTEXE): extra_dflags += -profile -profile=gc
