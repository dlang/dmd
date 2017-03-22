include ../common.mak

TESTS:=comparison

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS)
	@touch $@

$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

clean:
	rm -rf $(ROOT)
