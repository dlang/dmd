normal := basic
merge := merge merge_true
TESTS := $(normal) $(merge) no_code merge_override count_fragments fragments
include ../common.mak

normal_tests := $(normal:%=$(ROOT)/%.done)
merge_tests := $(merge:%=$(ROOT)/%.done)

extra_dflags += -cov

DIFF:=diff --strip-trailing-cr
SED:=sed

ifneq (,$(filter $(OS),freebsd osx))
    SED_INPLACE:=-i ''
else
    SED_INPLACE:=-i''
endif

$(normal_tests): $(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	@$(RM) $(ROOT)/src-$*.lst
	$< $(ROOT)
ifeq (windows,$(OS))
	$(SED) $(SED_INPLACE) 's:^src\\:src/:g' $(ROOT)/src-$*.lst
endif
	$(DIFF) src-$*.lst.exp $(ROOT)/src-$*.lst
	@touch $@

$(merge_tests): $(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	@$(RM) $(ROOT)/src-$*.lst
	$< $(ROOT)
	$< $(ROOT)
ifeq (windows,$(OS))
	$(SED) $(SED_INPLACE) 's:^src\\:src/:g' $(ROOT)/src-$*.lst
endif
	$(DIFF) src-$*.lst.exp $(ROOT)/src-$*.lst
	@touch $@

$(ROOT)/merge_override.done: $(ROOT)/%.done: $(ROOT)/%$(DOTEXE) $(ROOT)/1/$(SRC)/%.d $(ROOT)/2/$(SRC)/%.d src-%.lst_1.exp src-%.lst_2.exp
	@echo Testing $*
	@$(RM) $(ROOT)/src-$*.lst

	$< $(ROOT) $(ROOT)/1
ifeq (windows,$(OS))
	$(SED) $(SED_INPLACE) 's:^src\\:src/:g' $(ROOT)/src-$*.lst
endif
	$(DIFF) src-$*.lst_1.exp $(ROOT)/src-$*.lst

	$< $(ROOT) $(ROOT)/2
ifeq (windows,$(OS))
	$(SED) $(SED_INPLACE) 's:^src\\:src/:g' $(ROOT)/src-$*.lst
endif
	$(DIFF) src-$*.lst_2.exp $(ROOT)/src-$*.lst

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
	@$(RM) $(ROOT)/src-$*.lst
	$< $(ROOT)
	$< $(ROOT)
ifeq (windows,$(OS))
	$(SED) $(SED_INPLACE) 's:^src\\:src/:g' $(ROOT)/src-$*.lst
	$(SED) $(SED_INPLACE) 's:^src\\:src/:g' $(ROOT)/src-$*_imp.lst
endif
	$(DIFF) src-$*.lst.exp $(ROOT)/src-$*.lst
	$(DIFF) src-$*_imp.lst.exp $(ROOT)/src-$*_imp.lst
	@touch $@
$(ROOT)/no_code$(DOTEXE): $(SRC)/no_code_imp.d
$(ROOT)/no_code$(DOTEXE): extra_sources += $(SRC)/no_code_imp.d

$(ROOT)/fragments.done: $(ROOT)/fragments$(DOTEXE) $(SRC)/fragment-lines.txt
	@$(RM) $(ROOT)/src-fragment-lines.lst
	$< $(ROOT)
	$< $(ROOT) reverse
	grep -Eq '^[[:space:]]*1\|both' $(ROOT)/src-fragment-lines.lst
	grep -Eq '^[[:space:]]*6\|count only' $(ROOT)/src-fragment-lines.lst
	grep -Eq '^0000000\|unhit' $(ROOT)/src-fragment-lines.lst
	@touch $@

$(ROOT)/count_fragments.done: $(ROOT)/count_fragments$(DOTEXE) $(SRC)/count-lines.txt
	@$(RM) $(ROOT)/src-count-lines.lst $(ROOT)/src-.-count-lines.lst
	$< $(ROOT)
	grep -Eq '^[[:space:]]*5\|overlap' $(ROOT)/src-count-lines.lst
	grep -Eq '^[[:space:]]*3\|second only' $(ROOT)/src-count-lines.lst
	grep -Eq '^0000000\|unhit' $(ROOT)/src-count-lines.lst
	test ! -f $(ROOT)/src-.-count-lines.lst
	@$(RM) $(ROOT)/src-count-lines.lst $(ROOT)/src-count_fragments.lst
	if $< $(ROOT) stale 2>$(ROOT)/count-stale.err; then exit 1; else test $$? -eq 1; fi
	grep -F 'different source lengths' $(ROOT)/count-stale.err
	test ! -f $(ROOT)/src-count-lines.lst
	test -s $(ROOT)/src-count_fragments.lst
	@touch $@
