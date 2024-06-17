include ../common.mak

TESTS:=test19433 test20459 test22523

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%$(DOTEXE): $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

$(ROOT)/test19433.done: $(ROOT)/test19433$(DOTEXE)
	@echo Testing test19433
	$(QUIET)$(ROOT)/test19433 --DRT-dont-eat-me
	@touch $@

$(ROOT)/test20459.done: $(ROOT)/test20459$(DOTEXE)
	@echo Testing test20459
	$(QUIET)$(ROOT)/test20459 foo bar -- --DRT-gcopts=profile:1
	@touch $@


$(ROOT)/test22523.done: $(SRC)/test22523.d
	@echo Testing $<
	$(QUIET)$(DMD) $(DFLAGS) -unittest -of$(ROOT)/test22523$(DOTEXE) $<
	$(QUIET)$(ROOT)/test22523 -- --DRT-testmode=run-main
	@touch $@

clean:
	rm -rf $(ROOT)
