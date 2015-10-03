include ../common.mak

DFLAGS+=-cov

NORMAL_TESTS:=$(addprefix $(ROOT)/,$(addsuffix .done,basic no_code))
MERGE_TESTS:=$(addprefix $(ROOT)/,$(addsuffix .done,merge merge_true))

DIFF:=diff

.PHONY: all clean
all: $(NORMAL_TESTS) $(MERGE_TESTS)

$(NORMAL_TESTS): $(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	@rm -f $(ROOT)/src-$*.lst
	$(QUIET)$(ROOT)/$* $(ROOT) $(RUN_ARGS)
	$(QUIET)$(DIFF) src-$*.lst.exp $(ROOT)/src-$*.lst
	@touch $@

$(MERGE_TESTS): $(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	@rm -f $(ROOT)/src-$*.lst
	$(QUIET)$(ROOT)/$* $(ROOT) $(RUN_ARGS)
	$(QUIET)$(ROOT)/$* $(ROOT) $(RUN_ARGS)
	$(QUIET)$(DIFF) src-$*.lst.exp $(ROOT)/src-$*.lst
	@touch $@

$(ROOT)/no_code.done: $(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	@rm -f $(ROOT)/src-$*.lst
	$(QUIET)$(ROOT)/$* $(ROOT) $(RUN_ARGS)
	$(QUIET)$(ROOT)/$* $(ROOT) $(RUN_ARGS)
	$(QUIET)$(DIFF) src-$*.lst.exp $(ROOT)/src-$*.lst
	$(QUIET)$(DIFF) src-$*_imp.lst.exp $(ROOT)/src-$*_imp.lst
	@touch $@

$(ROOT)/no_code: $(SRC)/no_code_imp.d
$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$(ROOT)/$* $^

clean:
	rm -rf $(ROOT) *.lst
