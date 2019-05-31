include ../common.mak

TESTS:=test18828 test19416 test19421 test19561 test19924

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix ,$(TESTS))) $(addprefix $(ROOT)/,test19924.done)

$(ROOT)/test19924.done: $(ROOT)/%.done : $(ROOT)/%
	@echo Running $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS)
	@touch $@

$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) -betterC -of$@ $<

clean:
	rm -rf $(ROOT)
