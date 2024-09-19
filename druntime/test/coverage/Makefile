include ../common.mak

DFLAGS+=-cov

NORMAL_TESTS:=$(addprefix $(ROOT)/,$(addsuffix .done,basic))
MERGE_TESTS:=$(addprefix $(ROOT)/,$(addsuffix .done,merge merge_true))

DIFF:=diff --strip-trailing-cr
SED:=sed

ifeq ($(OS),$(filter $(OS),freebsd osx))
    SED_INPLACE:=-i ''
else
    SED_INPLACE:=-i''
endif

.PHONY: all clean
all: $(NORMAL_TESTS) $(MERGE_TESTS) $(ROOT)/no_code.done $(ROOT)/merge_override.done

$(NORMAL_TESTS): $(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	@rm -f $(ROOT)/src-$*.lst
	$(QUIET)$(ROOT)/$* $(ROOT) $(RUN_ARGS)
ifeq (windows,$(OS))
	$(QUIET)$(SED) $(SED_INPLACE) 's:^src\\:src/:g' $(ROOT)/src-$*.lst
endif
	$(QUIET)$(DIFF) src-$*.lst.exp $(ROOT)/src-$*.lst
	@touch $@

$(MERGE_TESTS): $(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	@rm -f $(ROOT)/src-$*.lst
	$(QUIET)$(ROOT)/$* $(ROOT) $(RUN_ARGS)
	$(QUIET)$(ROOT)/$* $(ROOT) $(RUN_ARGS)
ifeq (windows,$(OS))
	$(QUIET)$(SED) $(SED_INPLACE) 's:^src\\:src/:g' $(ROOT)/src-$*.lst
endif
	$(QUIET)$(DIFF) src-$*.lst.exp $(ROOT)/src-$*.lst
	@touch $@

$(ROOT)/merge_override.done: $(ROOT)/%.done: $(ROOT)/%$(DOTEXE) $(ROOT)/1/$(SRC)/%.d $(ROOT)/2/$(SRC)/%.d src-%.lst_1.exp src-%.lst_2.exp
	@echo Testing $*
	@rm -f $(ROOT)/src-$*.lst
	$(QUIET)$(ROOT)/$* $(ROOT) $(ROOT)/1
ifeq (windows,$(OS))
	$(QUIET)$(SED) $(SED_INPLACE) 's:^src\\:src/:g' $(ROOT)/src-$*.lst
endif
	$(QUIET)$(DIFF) src-$*.lst_1.exp $(ROOT)/src-$*.lst
	$(QUIET)$(ROOT)/$* $(ROOT) $(ROOT)/2
ifeq (windows,$(OS))
	$(QUIET)$(SED) $(SED_INPLACE) 's:^src\\:src/:g' $(ROOT)/src-$*.lst
endif
	$(QUIET)$(DIFF) src-$*.lst_2.exp $(ROOT)/src-$*.lst
	@touch $@

$(ROOT)/1/$(SRC)/merge_override.d: $(SRC)/merge_override.d | $(ROOT)/1/$(SRC)
	cp $< $@
$(ROOT)/2/$(SRC)/merge_override.d: $(SRC)/merge_override.d | $(ROOT)/2/$(SRC)
	cp $< $@
	$(SED) $(SED_INPLACE) 's/CHANGE_VAR/CHANGEVAR/g' $@
$(ROOT)/1/$(SRC) $(ROOT)/2/$(SRC):
	mkdir -p $@

$(ROOT)/no_code.done: $(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	@rm -f $(ROOT)/src-$*.lst
	$(QUIET)$(ROOT)/$* $(ROOT) $(RUN_ARGS)
	$(QUIET)$(ROOT)/$* $(ROOT) $(RUN_ARGS)
ifeq (windows,$(OS))
	$(QUIET)$(SED) $(SED_INPLACE) 's:^src\\:src/:g' $(ROOT)/src-$*.lst
	$(QUIET)$(SED) $(SED_INPLACE) 's:^src\\:src/:g' $(ROOT)/src-$*_imp.lst
endif
	$(QUIET)$(DIFF) src-$*.lst.exp $(ROOT)/src-$*.lst
	$(QUIET)$(DIFF) src-$*_imp.lst.exp $(ROOT)/src-$*_imp.lst
	@touch $@

$(ROOT)/no_code$(DOTEXE): $(SRC)/no_code_imp.d
$(ROOT)/%$(DOTEXE): $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $^

clean:
	rm -rf $(ROOT) *.lst
