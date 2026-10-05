HANDLER_TESTS := good goodn bad badn na
PERTEST_TESTS := pertest_pass pertest_fail pertest_legacy pertest_runmain pertest_none \
    pertest_filter pertest_filter_errors pertest_list
TESTS := $(HANDLER_TESTS) metadata metadata_disabled $(PERTEST_TESTS)

include ../common.mak

$(ROOT)/good.done: hasmain=0
$(ROOT)/goodn.done: hasmain=0
$(ROOT)/bad.done: hasmain=0
$(ROOT)/badn.done: hasmain=0
$(ROOT)/na.done: hasmain=1

$(ROOT)/good.done: retcode=0
$(ROOT)/goodn.done: retcode=0
$(ROOT)/bad.done: retcode=1
$(ROOT)/badn.done: retcode=1
$(ROOT)/na.done: retcode=0

$(ROOT)/good.done: testtext=
$(ROOT)/goodn.done: testtext=passed
$(ROOT)/bad.done: testtext=
$(ROOT)/badn.done: testtext=FAILED
$(ROOT)/na.done: testtext=

$(ROOT)/good$(DOTEXE): private extra_dflags += -version=PassNoPrintout
$(ROOT)/goodn$(DOTEXE): private extra_dflags += -version=GoodTests
$(ROOT)/bad$(DOTEXE): private extra_dflags += -version=FailNoPrintout
$(ROOT)/badn$(DOTEXE): private extra_dflags += -version=FailedTests
$(ROOT)/na$(DOTEXE): private extra_dflags += -version=NoTests

# $(OBJDIR)/good.done $(OBJDIR)/bad.done [...]: $(OBJDIR)/%.done: $(OBJDIR)/%$(DOTEXE):
#
# Forces the tests to be matched by this rule instead of being matched
# by the `$(OBJDIR)/%$(DOTEXE)` (`$(OBJDIR)/%` on posix) rule at the
# end:
$(HANDLER_TESTS:%=$(OBJDIR)/%.done): $(OBJDIR)/%.done: $(OBJDIR)/%$(DOTEXE)
	@echo Testing $*
	$(TIMELIMIT)$< > $@ 2>&1; test $$? -eq $(retcode)
	test $(hasmain) -eq 0 || grep -q main $@
	test $(hasmain) -eq 1 || ! grep -q main $@
	test -z "$(testtext)" || grep -q "$(testtext) unittests" $@
	test -n "$(testtext)" || ! grep -q "unittests" $@

$(OBJDIR)/%$(DOTEXE): customhandler.d
	$(LINK.d) $< $(extra_sources) $(extra_ldlibs.d) $(LDLIBS.d) $(OUTPUT_OPTION.d)

$(OBJDIR)/metadata$(DOTEXE): metadata.d $(DMD_DEP) $(DRUNTIME_DEP) | $(OBJDIR)
	$(LINK.d) -unittest $< $(extra_ldlibs.d) $(LDLIBS.d) $(OUTPUT_OPTION.d)

$(OBJDIR)/metadata_disabled$(DOTEXE): metadata.d $(DMD_DEP) $(DRUNTIME_DEP) | $(OBJDIR)
	$(LINK.d) $< $(extra_ldlibs.d) $(LDLIBS.d) $(OUTPUT_OPTION.d)

pertest_sources := pertest.d pertestpkg/sub.d

$(OBJDIR)/pertest_pass$(DOTEXE): $(pertest_sources) $(DMD_DEP) $(DRUNTIME_DEP) | $(OBJDIR)
	$(LINK.d) -unittest $(pertest_sources) $(extra_ldlibs.d) $(LDLIBS.d) $(OUTPUT_OPTION.d)

$(OBJDIR)/pertest_fail$(DOTEXE): $(pertest_sources) $(DMD_DEP) $(DRUNTIME_DEP) | $(OBJDIR)
	$(LINK.d) -unittest -version=FailingTest $(pertest_sources) $(extra_ldlibs.d) $(LDLIBS.d) $(OUTPUT_OPTION.d)

$(OBJDIR)/pertest_none$(DOTEXE): $(pertest_sources) $(DMD_DEP) $(DRUNTIME_DEP) | $(OBJDIR)
	$(LINK.d) $(pertest_sources) $(extra_ldlibs.d) $(LDLIBS.d) $(OUTPUT_OPTION.d)

# The default runner executes each unittest block on its own.
$(OBJDIR)/pertest_pass.done: $(OBJDIR)/pertest_pass$(DOTEXE)
	@echo Testing pertest_pass
	$(TIMELIMIT)$< > $(OBJDIR)/pertest_pass.out 2>&1; test $$? -eq 0
	grep -q '^pertest: 4 passed' $(OBJDIR)/pertest_pass.out
	grep -q '^pertestpkg\.sub: 1 passed' $(OBJDIR)/pertest_pass.out
	grep -q '^5 unittests passed' $(OBJDIR)/pertest_pass.out
	if grep -q FAILED $(OBJDIR)/pertest_pass.out; then exit 1; fi
	if grep -q main $(OBJDIR)/pertest_pass.out; then exit 1; fi
	@touch $@

# A failing unittest block is reported by name and does not stop the others.
$(OBJDIR)/pertest_fail.done: $(OBJDIR)/pertest_fail$(DOTEXE)
	@echo Testing pertest_fail
	$(TIMELIMIT)$< > $(OBJDIR)/pertest_fail.out 2>&1; test $$? -eq 1
	grep -q '^pertest\.__unittest_L[0-9]*_C1: FAILED' $(OBJDIR)/pertest_fail.out
	test "$$(grep -c '^pertest\.__unittest_L[0-9]*_C1: FAILED' $(OBJDIR)/pertest_fail.out)" -eq 2
	grep -q '^pertest\.d([0-9]*): \[unittest\] boom' $(OBJDIR)/pertest_fail.out
	grep -q '^object\.Exception@pertest\.d(' $(OBJDIR)/pertest_fail.out
	grep -q 'thrown' $(OBJDIR)/pertest_fail.out
	grep -q '^after' $(OBJDIR)/pertest_fail.out
	grep -q '^pertest: 2 passed, 2 FAILED' $(OBJDIR)/pertest_fail.out
	grep -q '^pertestpkg\.sub: 1 passed' $(OBJDIR)/pertest_fail.out
	grep -q '^2/5 unittests FAILED' $(OBJDIR)/pertest_fail.out
	test "$$(grep -n ': FAILED' $(OBJDIR)/pertest_fail.out | head -n 1 | cut -d: -f1)" -lt "$$(grep -n '\[unittest\] boom' $(OBJDIR)/pertest_fail.out | head -n 1 | cut -d: -f1)"
	tail -n 1 $(OBJDIR)/pertest_fail.out | grep -q '^2/5 unittests FAILED'
	if grep -q '^main' $(OBJDIR)/pertest_fail.out; then exit 1; fi
	test -z "$$($(TIMELIMIT)$< 2>/dev/null)"
	@touch $@

# An explicit --DRT-testmode selects the per-module runner.
$(OBJDIR)/pertest_legacy.done: $(OBJDIR)/pertest_fail$(DOTEXE)
	@echo Testing pertest_legacy
	$(TIMELIMIT)$< --DRT-testmode=test-or-main > $(OBJDIR)/pertest_legacy.out 2>&1; test $$? -eq 1
	grep -q '^1/2 modules FAILED unittests' $(OBJDIR)/pertest_legacy.out
	grep -q '^pertest\.d([0-9]*): \[unittest\] boom' $(OBJDIR)/pertest_legacy.out
	if grep -q after $(OBJDIR)/pertest_legacy.out; then exit 1; fi
	if grep -q 'passed' $(OBJDIR)/pertest_legacy.out; then exit 1; fi
	if grep -q main $(OBJDIR)/pertest_legacy.out; then exit 1; fi
	$(TIMELIMIT)$< --DRT-testmode=test-or-main 2>/dev/null | grep -q '^pertest\.d([0-9]*): \[unittest\] boom'
	$(TIMELIMIT)$< --DRT-testmode=test-or-main 2>&1 >/dev/null | grep -q '^1/2 modules FAILED unittests'
	@touch $@

$(OBJDIR)/pertest_runmain.done: $(OBJDIR)/pertest_pass$(DOTEXE)
	@echo Testing pertest_runmain
	$(TIMELIMIT)$< --DRT-testmode=run-main > $(OBJDIR)/pertest_runmain.out 2>&1; test $$? -eq 0
	grep -q '^after' $(OBJDIR)/pertest_runmain.out
	grep -q '^main' $(OBJDIR)/pertest_runmain.out
	if grep -q 'passed' $(OBJDIR)/pertest_runmain.out; then exit 1; fi
	@touch $@

$(OBJDIR)/pertest_none.done: $(OBJDIR)/pertest_none$(DOTEXE)
	@echo Testing pertest_none
	$(TIMELIMIT)$< > $(OBJDIR)/pertest_none.out 2>&1; test $$? -eq 0
	grep -q '^main' $(OBJDIR)/pertest_none.out
	if grep -q 'passed' $(OBJDIR)/pertest_none.out; then exit 1; fi
	@touch $@

# --DRT-testfilter selects unittests by package, module or full name.
$(OBJDIR)/pertest_filter.done: out=$(OBJDIR)/pertest_filter.out
$(OBJDIR)/pertest_filter.done: $(OBJDIR)/pertest_fail$(DOTEXE)
	@echo Testing pertest_filter
	$(TIMELIMIT)$< --DRT-testfilter=pertestpkg > $(out) 2>&1; test $$? -eq 0
	grep -q '^pertestpkg\.sub: 1 passed' $(out)
	grep -q '^1 unittests passed' $(out)
	if grep -q '^pertest:' $(out); then exit 1; fi
	$(TIMELIMIT)$< --DRT-testfilter=pertest > $(out) 2>&1; test $$? -eq 1
	grep -q '^pertest: 2 passed, 2 FAILED' $(out)
	grep -q '^2/4 unittests FAILED' $(out)
	if grep -q pertestpkg $(out); then exit 1; fi
	$(TIMELIMIT)$< --DRT-testfilter=pertest.__unittest_L14_C1 > $(out) 2>&1; test $$? -eq 0
	grep -q '^after' $(out)
	grep -q '^pertest: 1 passed' $(out)
	grep -q '^1 unittests passed' $(out)
	$(TIMELIMIT)$< --DRT-testfilter=pertestpkg.sub,pertest.__unittest_L5_C1 > $(out) 2>&1; test $$? -eq 0
	grep -q '^2 unittests passed' $(out)
	if grep -q after $(out); then exit 1; fi
	$(TIMELIMIT)$< --DRT-testfilter=-pertest.__unittest_L9_C1,-pertest.__unittest_L25_C1 > $(out) 2>&1; test $$? -eq 0
	grep -q '^3 unittests passed' $(out)
	$(TIMELIMIT)$< --DRT-testfilter=pertest,-pertest.__unittest_L9_C1,-pertest.__unittest_L25_C1 > $(out) 2>&1; test $$? -eq 0
	grep -q '^2 unittests passed' $(out)
	$(TIMELIMIT)$< --DRT-testfilter=pertest,-pertest.__unittest_L9_C1 > $(out) 2>&1; test $$? -eq 1
	grep -q '^1/3 unittests FAILED' $(out)
	@touch $@

# A filter that cannot do what it says fails without running anything.
$(OBJDIR)/pertest_filter_errors.done: out=$(OBJDIR)/pertest_filter_errors.out
$(OBJDIR)/pertest_filter_errors.done: $(OBJDIR)/pertest_fail$(DOTEXE) $(OBJDIR)/pertest_none$(DOTEXE)
	@echo Testing pertest_filter_errors
	$(TIMELIMIT)$< --DRT-testfilter=pertestpkg,nosuch > $(out) 2>&1; test $$? -eq 1
	grep -q "'nosuch' does not match any unittest" $(out)
	if grep -q 'passed' $(out); then exit 1; fi
	$(TIMELIMIT)$< --DRT-testfilter=pertestp > $(out) 2>&1; test $$? -eq 1
	grep -q "'pertestp' does not match any unittest" $(out)
	$(TIMELIMIT)$< --DRT-testfilter=pertest.__unittest_L14 > $(out) 2>&1; test $$? -eq 1
	if grep -q after $(out); then exit 1; fi
	$(TIMELIMIT)$< --DRT-testfilter=pertestpkg,-nosuch > $(out) 2>&1; test $$? -eq 1
	grep -q "'-nosuch' does not match any unittest" $(out)
	$(TIMELIMIT)$< --DRT-testfilter=pertestpkg,-pertestpkg.sub > $(out) 2>&1; test $$? -eq 1
	grep -q 'no unittests selected' $(out)
	$(TIMELIMIT)$< --DRT-testfilter=pertestpkg,,pertest > $(out) 2>&1; test $$? -eq 1
	grep -q 'empty selector' $(out)
	$(TIMELIMIT)$< --DRT-testmode=run-main --DRT-testfilter=pertestpkg > $(out) 2>&1; test $$? -eq 1
	grep -q 'testmode=run-main' $(out)
	if grep -q '^main' $(out); then exit 1; fi
	$(TIMELIMIT)$< --DRT-testmode=bogus > $(out) 2>&1; test $$? -eq 1
	grep -q 'Unknown --DRT-testmode option: bogus' $(out)
	if grep -q after $(out); then exit 1; fi
	if grep -q '^main' $(out); then exit 1; fi
	$(TIMELIMIT)$(OBJDIR)/pertest_none$(DOTEXE) --DRT-testfilter=pertest > $(out) 2>&1; test $$? -eq 1
	grep -q "'pertest' does not match any unittest" $(out)
	if grep -q '^main' $(out); then exit 1; fi
	@touch $@

# --DRT-testmode=list prints the names --DRT-testfilter accepts on stdout.
$(OBJDIR)/pertest_list.done: out=$(OBJDIR)/pertest_list.out
$(OBJDIR)/pertest_list.done: $(OBJDIR)/pertest_fail$(DOTEXE) $(OBJDIR)/pertest_none$(DOTEXE)
	@echo Testing pertest_list
	$(TIMELIMIT)$< --DRT-testmode=list > $(out); test $$? -eq 0
	grep -q '^pertest\.__unittest_L5_C1' $(out)
	grep -q '^pertest\.__unittest_L9_C1' $(out)
	grep -q '^pertest\.__unittest_L14_C1' $(out)
	grep -q '^pertest\.__unittest_L25_C1' $(out)
	grep -q '^pertestpkg\.sub\.__unittest_L3_C1' $(out)
	test $$(grep -c . $(out)) -eq 5
	$(TIMELIMIT)$< --DRT-testmode=list --DRT-testfilter=pertest,-pertest.__unittest_L9_C1 > $(out) 2>&1; test $$? -eq 0
	grep -q '^pertest\.__unittest_L5_C1' $(out)
	grep -q '^pertest\.__unittest_L14_C1' $(out)
	grep -q '^pertest\.__unittest_L25_C1' $(out)
	test $$(grep -c . $(out)) -eq 3
	$(TIMELIMIT)$< --DRT-testmode=list --DRT-testfilter=nosuch > $(out) 2>&1; test $$? -eq 1
	grep -q "'nosuch' does not match any unittest" $(out)
	$(TIMELIMIT)$(OBJDIR)/pertest_none$(DOTEXE) --DRT-testmode=list > $(out) 2>&1; test $$? -eq 0
	test $$(grep -c . $(out)) -eq 0
	@touch $@
