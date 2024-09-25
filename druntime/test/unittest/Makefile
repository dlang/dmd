TESTS := good goodn bad badn na

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
$(TESTS:%=$(OBJDIR)/%.done): $(OBJDIR)/%.done: $(OBJDIR)/%$(DOTEXE)
	@echo Testing $*
	$(TIMELIMIT)$< > $@ 2>&1; test $$? -eq $(retcode)
	test $(hasmain) -eq 0 || grep -q main $@
	test $(hasmain) -eq 1 || ! grep -q main $@
	test -z "$(testtext)" || grep -q "$(testtext) unittests" $@
	test -n "$(testtext)" || ! grep -q "unittests" $@

$(OBJDIR)/%$(DOTEXE): customhandler.d
	$(LINK.d) $< $(extra_sources) $(extra_ldlibs.d) $(LDLIBS.d) $(OUTPUT_OPTION.d)
