include ../common.mak

TESTS:=good goodn bad badn na

DIFF:=diff
SED:=sed

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/good.done: HASMAIN=0
$(ROOT)/goodn.done: HASMAIN=0
$(ROOT)/bad.done: HASMAIN=0
$(ROOT)/badn.done: HASMAIN=0
$(ROOT)/na.done: HASMAIN=1

$(ROOT)/good.done: RETCODE=0
$(ROOT)/goodn.done: RETCODE=0
$(ROOT)/bad.done: RETCODE=1
$(ROOT)/badn.done: RETCODE=1
$(ROOT)/na.done: RETCODE=0

$(ROOT)/good.done: VER=PassNoPrintout
$(ROOT)/goodn.done: VER=GoodTests
$(ROOT)/bad.done: VER=FailNoPrintout
$(ROOT)/badn.done: VER=FailedTests
$(ROOT)/na.done: VER=NoTests

$(ROOT)/good.done: TESTTEXT=
$(ROOT)/goodn.done: TESTTEXT=passed
$(ROOT)/bad.done: TESTTEXT=
$(ROOT)/badn.done: TESTTEXT=FAILED
$(ROOT)/na.done: TESTTEXT=

$(ROOT)/%.done: customhandler.d
	@echo Testing $*
	$(QUIET)$(DMD) $(DFLAGS) -of$(ROOT)/tester_$(patsubst %.done,%, $(notdir $@)) customhandler.d -version=$(VER)
	$(QUIET)$(TIMELIMIT)$(ROOT)/tester_$(patsubst %.done,%, $(notdir $@)) > $@ 2>&1; test $$? -eq $(RETCODE)
	$(QUIET)test $(HASMAIN) -eq 0 || grep -q main $@
	$(QUIET)test $(HASMAIN) -eq 1 || ! grep -q main $@
	$(QUIET)test -z "$(TESTTEXT)" || grep -q "unittests $(TESTTEXT)" $@
	$(QUIET)test -n "$(TESTTEXT)" || ! grep -q "unittests" $@
clean:
	rm -rf $(GENERATED)
