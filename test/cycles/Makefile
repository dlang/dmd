include ../common.mak

TESTS:=cycle_ignore cycle_abort cycle_print cycle_deprecate

DIFF:=diff
SED:=sed

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/cycle_ignore.done: RETCODE=0
$(ROOT)/cycle_ignore.done: LINES=0
$(ROOT)/cycle_abort.done: RETCODE=1
$(ROOT)/cycle_abort.done: LINES=7
$(ROOT)/cycle_print.done: RETCODE=0
$(ROOT)/cycle_print.done: LINES=6
$(ROOT)/cycle_deprecate.done: RETCODE=0
$(ROOT)/cycle_deprecate.done: LINES=4
$(ROOT)/%.done: $(ROOT)/test_cycles
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/test_cycles --DRT-oncycle=$(patsubst cycle_%.done,%, $(notdir $@)) > $@ 2>&1; test $$? -eq $(RETCODE)
	test `cat $@ | wc -l` -eq $(LINES)

$(ROOT)/test_cycles: $(SRC)/*.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $^

clean:
	rm -rf $(GENERATED)
