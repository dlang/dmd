include ../common.mak

TESTS:=comparison isbaseof enum_

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
