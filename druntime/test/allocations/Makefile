include ../common.mak

TESTS:=overflow_from_zero overflow_from_existing alloc_from_assert

DIFF:=diff
SED:=sed

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/alloc_from_assert.done: $(ROOT)/alloc_from_assert$(DOTEXE)
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/alloc_from_assert $(RUN_ARGS)
	@touch $@

$(ROOT)/overflow_from_zero.done: STDERR_EXP="Memory allocation failed"
$(ROOT)/overflow_from_existing.done: STDERR_EXP="Memory allocation failed"
$(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(NEGATE) $(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS) 2>&1 1>/dev/null | head -n 2 | grep -qF $(STDERR_EXP)
	@touch $@

$(ROOT)/unittest_assert$(DOTEXE): DFLAGS+=-unittest -version=CoreUnittest
$(ROOT)/%$(DOTEXE): $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

clean:
	rm -rf $(GENERATED)
