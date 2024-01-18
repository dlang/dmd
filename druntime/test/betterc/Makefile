include ../common.mak

TESTS:=test18828 test19416 test19421 test19561 test20088 test20613 test19924 test22336 test19933

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Running $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS)
	@touch $@

# for the Windows MinGW CI job:
ifneq (,$(findstring -mscrtlib=msvcrt120,$(DFLAGS)))
# DFLAGS=-mscrtlib=msvcrt120 takes precedence over any command line flags, so
# specify vcruntime140.lib explicitly for using mingw with Universal CRT.
$(ROOT)/test19933$(DOTEXE): $(SRC)/test19933.d
	$(QUIET)$(DMD) $(MODEL_FLAG) -I../../src -betterC -of$@ $< -Lvcruntime140.lib -Llegacy_stdio_definitions.lib -L/NODEFAULTLIB:msvcrt120.lib
endif

$(ROOT)/%$(DOTEXE): $(SRC)/%.d
	$(QUIET)$(DMD) $(MODEL_FLAG) -I../../src -betterC -of$@ $<

clean:
	rm -rf $(ROOT)
