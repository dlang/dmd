include ../common.mak

TESTS:=profile profilegc both

DIFF:=diff
GREP:=grep

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/profile.done: DFLAGS+=-profile
$(ROOT)/profile.done: $(ROOT)/%.done: $(ROOT)/%
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
$(ROOT)/profilegc.done: $(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	@rm -f $(ROOT)/myprofilegc.log
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(ROOT)/myprofilegc.log
	$(QUIET)$(DIFF) myprofilegc.log.$(OS).$(MODEL).exp $(ROOT)/myprofilegc.log
	@touch $@

$(ROOT)/both.done: DFLAGS+=-profile -profile=gc
$(ROOT)/both.done: $(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	@rm -f $(ROOT)/both.log $(ROOT)/both.def $(ROOT)/bothgc.log
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(ROOT)/both.log $(ROOT)/both.def $(ROOT)/bothgc.log
	$(QUIET)$(GREP) -q '1 .*_Dmain' $(ROOT)/both.log
	$(QUIET)$(GREP) -q '1000 .*both.Num\* both.foo(uint)' $(ROOT)/both.log
	$(QUIET) cat $(ROOT)/both.def
	$(QUIET) sort $(ROOT)/both.def -o $(ROOT)/both.def
	$(QUIET)(sort bothnew.def.exp | $(DIFF) - $(ROOT)/both.def)
	$(QUIET)$(DIFF) bothgc.log.exp $(ROOT)/bothgc.log
	@touch $@

$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$(ROOT)/$* $<

clean:
	rm -rf $(GENERATED) *.log *.def
