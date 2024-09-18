include ../common.mak

TESTS:=cycle_ignore cycle_abort cycle_print cycle_deprecate

DIFF:=diff
SED:=sed

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/cycle_ignore.done: RETCODE=0
$(ROOT)/cycle_ignore.done: LINES=0
$(ROOT)/cycle_abort.done: RETCODE=1
# LINK_SHARED causes the abort message to contain trace lines.
abort_lines := $(if $(filter windows,$(OS)),8,7)
abort_lines := $(if $(LINK_SHARED),,$(abort_lines))
$(ROOT)/cycle_abort.done: LINES=$(abort_lines)
$(ROOT)/cycle_print.done: RETCODE=0
$(ROOT)/cycle_print.done: LINES=6
$(ROOT)/cycle_deprecate.done: RETCODE=1
# ditto for deprecate
deprecate_lines := $(if $(filter windows,$(OS)),9,8)
deprecate_lines := $(if $(LINK_SHARED),,$(deprecate_lines))
$(ROOT)/cycle_deprecate.done: LINES=$(deprecate_lines)
$(ROOT)/%.done: $(ROOT)/test_cycles$(DOTEXE)
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/test_cycles --DRT-oncycle=$(patsubst cycle_%.done,%, $(notdir $@)) > $@ 2>&1; test $$? -eq $(RETCODE)
	[ -z "$(LINES)" ] || test `cat $@ | wc -l` -eq $(LINES)

$(ROOT)/test_cycles$(DOTEXE): $(SRC)/*.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $^

clean:
	rm -rf $(ROOT)
