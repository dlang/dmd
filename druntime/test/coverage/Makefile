include ../common.mak

DFLAGS+=-cov

NORMAL_TESTS:=$(addprefix $(ROOT)/,$(addsuffix .done,basic))
MERGE_TESTS:=$(addprefix $(ROOT)/,$(addsuffix .done,merge merge_true))

DIFF:=diff
SED:=sed

ifeq ($(OS),$(filter $(OS),freebsd osx))
	SED_INPLACE:=-i ''
else
	SED_INPLACE:=-i''
endif

.PHONY: all clean
all: $(NORMAL_TESTS) $(MERGE_TESTS) $(ROOT)/no_code.done $(ROOT)/merge_override.done

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

$(ROOT)/merge_override.done: $(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	@rm -f $(ROOT)/src-$*.lst
	$(QUIET)$(SED) $(SED_INPLACE) 's/CHANGEVAR/CHANGE_VAR/g' src/$*.d
	$(QUIET)$(ROOT)/$* $(ROOT) $(RUN_ARGS)
	$(QUIET)$(SED) $(SED_INPLACE) 's/CHANGE_VAR/CHANGEVAR/g' src/$*.d
	$(QUIET)$(DIFF) src-$*.lst_1.exp $(ROOT)/src-$*.lst
	$(QUIET)$(ROOT)/$* $(ROOT) $(RUN_ARGS)
	$(QUIET)$(SED) $(SED_INPLACE) 's/CHANGEVAR/CHANGE_VAR/g' src/$*.d
	$(QUIET)$(DIFF) src-$*.lst_2.exp $(ROOT)/src-$*.lst
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
	rm -rf $(GENERATED) *.lst
