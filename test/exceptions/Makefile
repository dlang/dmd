include ../common.mak

TESTS:=stderr_msg unittest_assert invalid_memory_operation
ifeq ($(OS)-$(BUILD),linux-debug)
	TESTS:=$(TESTS) line_trace
endif
ifeq ($(OS)-$(BUILD),freebsd-debug)
	TESTS:=$(TESTS) line_trace
endif

DIFF:=diff
SED:=sed

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/line_trace.done: $(ROOT)/line_trace
	@echo Testing line_trace
	$(QUIET)$(TIMELIMIT)$(ROOT)/line_trace $(RUN_ARGS) > $(ROOT)/line_trace.output
	$(QUIET)$(SED) "s/\[0x[0-9a-f]*\]/\[ADDR\]/g" $(ROOT)/line_trace.output | $(DIFF) line_trace.exp -
	@rm -f $(ROOT)/line_trace.output
	@touch $@

$(ROOT)/stderr_msg.done: STDERR_EXP="stderr_msg msg"
$(ROOT)/unittest_assert.done: STDERR_EXP="unittest_assert msg"
$(ROOT)/invalid_memory_operation.done: STDERR_EXP="InvalidMemoryOperationError"
$(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS) 2>&1 1>/dev/null | grep -qF $(STDERR_EXP)
	@touch $@

$(ROOT)/unittest_assert: DFLAGS+=-unittest
$(ROOT)/line_trace: DFLAGS+=-L--export-dynamic
$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

clean:
	rm -rf $(GENERATED)
