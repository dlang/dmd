include ../common.mak

TESTS:=profile profilegc both

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

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/profile.done: DFLAGS+=-profile
$(ROOT)/profile.done: $(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	@rm -f $(ROOT)/mytrace.log $(ROOT)/mytrace.def
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(ROOT)/mytrace.log $(ROOT)/mytrace.def
	$(QUIET)$(GREP) -q '1 .*_Dmain' $(ROOT)/mytrace.log
	$(QUIET)$(GREP) -q '1000 .*uint profile.foo(uint)' $(ROOT)/mytrace.log
	$(QUIET) cat $(ROOT)/mytrace.def
	$(QUIET) sort $(ROOT)/mytrace.def -o $(ROOT)/mytrace.def
	$(QUIET) (sort mytrace.def.exp | $(DIFF) - $(ROOT)/mytrace.def) || (sort mytrace.releaseopt.def.exp | $(DIFF) - $(ROOT)/mytrace.def)
	@touch $@

$(ROOT)/profilegc.done: DFLAGS+=-profile=gc
$(ROOT)/profilegc.done: $(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	@rm -f $(ROOT)/myprofilegc.log
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(ROOT)/myprofilegc.log
	$(QUIET)$(DIFF) \
		<($(GREP) -vF 'core.' myprofilegc.log.$(OS).$(shell echo $(MODEL) | cut -c 1-2).exp) \
		<($(GREP) -vF 'core.' $(ROOT)/myprofilegc.log)
	@touch $@

$(ROOT)/both.done: DFLAGS+=-profile -profile=gc
$(ROOT)/both.done: $(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	@rm -f $(ROOT)/both.log $(ROOT)/both.def $(ROOT)/bothgc.log
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(ROOT)/both.log $(ROOT)/both.def $(ROOT)/bothgc.log
	$(QUIET)$(GREP) -q '1 .*_Dmain' $(ROOT)/both.log
	$(QUIET)$(GREP) -q '1000 .*both.Num\* both.foo(uint)' $(ROOT)/both.log
	$(QUIET) cat $(ROOT)/both.def
	$(QUIET) sort $(ROOT)/both.def -o $(ROOT)/both.def
	$(QUIET)(sort bothnew.def.exp | $(DIFF) - $(ROOT)/both.def)
ifeq (windows,$(OS))
	$(QUIET)$(DIFF) \
		<($(GREP) -vF 'core.' bothgc.log.exp) \
		<($(GREP) -vF 'core.' $(ROOT)/bothgc.log | $(SED) 's: src\\\\: src/:g')
else
	$(QUIET)$(DIFF) \
		<($(GREP) -vF 'core.' bothgc.log.exp) \
		<($(GREP) -vF 'core.' $(ROOT)/bothgc.log)
endif
	@touch $@

$(ROOT)/%$(DOTEXE): $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$(ROOT)/$* $<

clean:
	rm -rf $(GENERATED) *.log *.def
