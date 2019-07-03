include ../common.mak

TESTS:=cpuid

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$< $(RUN_ARGS)
	@touch $@

$(ROOT)/cpuid: $(SRC)/cpuid.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

clean:
	rm -rf $(GENERATED)
