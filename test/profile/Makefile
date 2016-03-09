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
	$(QUIET)$(DIFF) mytrace.def.exp $(ROOT)/mytrace.def
	@touch $@

$(ROOT)/profilegc.done: DFLAGS+=-profile=gc
$(ROOT)/profilegc.done: $(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	@rm -f $(ROOT)/myprofilegc.log
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(ROOT)/myprofilegc.log
	$(QUIET)$(DIFF) myprofilegc.log.exp $(ROOT)/myprofilegc.log
	@touch $@

$(ROOT)/both.done: DFLAGS+=-profile -profile=gc
$(ROOT)/both.done: $(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	@rm -f $(ROOT)/both.log $(ROOT)/both.def $(ROOT)/bothgc.log
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(ROOT)/both.log $(ROOT)/both.def $(ROOT)/bothgc.log
	$(QUIET)$(GREP) -q '1 .*_Dmain' $(ROOT)/both.log
	$(QUIET)$(GREP) -q '1000 .*both.Num\* both.foo(uint)' $(ROOT)/both.log
	$(QUIET)$(DIFF) both.def.exp $(ROOT)/both.def
	$(QUIET)$(DIFF) bothgc.log.exp $(ROOT)/bothgc.log
	@touch $@

$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$(ROOT)/$* $<

clean:
	rm -rf $(GENERATED) *.log *.def
