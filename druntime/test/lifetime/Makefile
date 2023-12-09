include ../common.mak

TESTS:=large_aggregate_destroy_21097

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS)
	@touch $@

$(ROOT)/%$(DOTEXE): $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

clean:
	rm -rf $(ROOT)
