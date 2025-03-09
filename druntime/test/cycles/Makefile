TESTS:=cycle_ignore cycle_abort cycle_print cycle_deprecate
include ../common.mak

$(ROOT)/cycle_ignore.done: retcode=0
$(ROOT)/cycle_ignore.done: lines=0
$(ROOT)/cycle_abort.done: retcode=1
# LINK_SHARED causes the abort message to contain trace lines.
abort_lines := $(if $(filter windows,$(OS)),8,7)
abort_lines := $(if $(LINK_SHARED),,$(abort_lines))
$(ROOT)/cycle_abort.done: lines=$(abort_lines)
$(ROOT)/cycle_print.done: retcode=0
$(ROOT)/cycle_print.done: lines=6
$(ROOT)/cycle_deprecate.done: retcode=1
# ditto for deprecate
deprecate_lines := $(if $(filter windows,$(OS)),9,8)
deprecate_lines := $(if $(LINK_SHARED),,$(deprecate_lines))
$(ROOT)/cycle_deprecate.done: lines=$(deprecate_lines)
$(ROOT)/%.done: $(ROOT)/test_cycles$(DOTEXE)
	@echo Testing $*
	$(TIMELIMIT)$< --DRT-oncycle=$(@F:cycle_%.done=%) > $@ 2>&1; test $$? -eq $(retcode)
	[ -z "$(lines)" ] || test `cat $@ | wc -l` -eq $(lines)

$(ROOT)/test_cycles$(DOTEXE): $(SRC)/mod*.d
$(ROOT)/test_cycles$(DOTEXE): private extra_sources = $(wildcard $(SRC)/mod*.d)

.DELETE_ON_ERROR:
