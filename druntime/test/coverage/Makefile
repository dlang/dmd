normal := basic
merge := merge merge_true
TESTS := $(normal) $(merge) no_code merge_override report_open duplicate
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

# A failed report open must not abort during runtime shutdown.
$(ROOT)/report_open.done: $(ROOT)/basic$(DOTEXE)
	@test ! -e $(ROOT)/missing-report-directory
	$< $(ROOT)/missing-report-directory
	@test ! -e $(ROOT)/missing-report-directory
	@echo not-a-directory > $(ROOT)/report-destination-file
	$< $(ROOT)/report-destination-file
	@$(RM) $(ROOT)/report-destination-file
	@touch $@

ifeq (windows,$(OS))
all: $(ROOT)/long_report.done

# Each component is valid, but the complete path exceeds MAX_PATH.
long_component := aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
long_report_dir := $(ROOT)/coverage reports/$(long_component)/$(long_component)/$(long_component)
$(ROOT)/long_report.done: $(ROOT)/basic$(DOTEXE)
	@set -e; \
	trap '$(RM) -r "$(ROOT)/coverage reports"' EXIT; \
	mkdir -p "$(long_report_dir)"; \
	$(RM) "$(long_report_dir)/src-basic.lst"; \
	$< "$(long_report_dir)"; \
	$(SED) 's@^src.@src/@' < "$(long_report_dir)/src-basic.lst" > $(ROOT)/long-report.lst; \
	$(DIFF) src-basic.lst.exp $(ROOT)/long-report.lst
	@touch $@
endif

$(ROOT)/duplicate.done: $(ROOT)/duplicate$(DOTEXE) $(SRC)/duplicate-lines.txt
	@set -e; for path in same alias; do for order in forward reverse; do \
		$(RM) $(ROOT)/src-duplicate-lines.lst $(ROOT)/src-.-duplicate-lines.lst; \
		$< $(ROOT) $$path $$order; \
		grep -Eq '^[[:space:]]*5\|overlap' $(ROOT)/src-duplicate-lines.lst; \
		grep -Eq '^[[:space:]]*3\|second only' $(ROOT)/src-duplicate-lines.lst; \
		grep -Eq '^0000000\|unhit' $(ROOT)/src-duplicate-lines.lst; \
		test ! -f $(ROOT)/src-.-duplicate-lines.lst; \
	done; done
	@$(RM) $(ROOT)/src-duplicate-lines.lst
	$< $(ROOT) empty forward
	grep -F 'has no code' $(ROOT)/src-duplicate-lines.lst
	@$(RM) $(ROOT)/src-duplicate-lines.lst $(ROOT)/src-duplicate.lst
	@if $< $(ROOT) stale forward 2>$(ROOT)/duplicate.err; then exit 1; else test $$? -eq 1; fi
	grep -F 'different source lengths' $(ROOT)/duplicate.err
	test ! -f $(ROOT)/src-duplicate-lines.lst
	test -s $(ROOT)/src-duplicate.lst
	@touch $@
