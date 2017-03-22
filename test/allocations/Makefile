include ../common.mak

TESTS:=overflow_from_zero overflow_from_existing

DIFF:=diff
SED:=sed

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/overflow_from_zero.done: STDERR_EXP="Memory allocation failed"
$(ROOT)/overflow_from_existing.done: STDERR_EXP="Memory allocation failed"
$(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	$(NEGATE) $(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS) 2>&1 1>/dev/null | head -n 1 | grep -qF $(STDERR_EXP)
	@touch $@

$(ROOT)/unittest_assert: DFLAGS+=-unittest
$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

clean:
	rm -rf $(GENERATED)
