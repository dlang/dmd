normal := basic
merge := merge merge_true
TESTS := $(normal) $(merge) no_code merge_override
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
