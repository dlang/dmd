include ../common.mak

TESTS:=tlsgc_sections test_import tlsstack join_detach

# some .d files support Posix only
ifneq ($(OS),windows)
    TEST+=fiber_guard_page external_threads
endif

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

# segfault || bus error (OSX)
$(ROOT)/fiber_guard_page.done: $(ROOT)/%.done : $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS); rc=$$?; [ $$rc -eq 139 ] || [ $$rc -eq 138 ]
	@touch $@

$(ROOT)/external_threads.done: $(ROOT)/%.done : $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$*
	@touch $@

$(ROOT)/tlsgc_sections.done: $(ROOT)/%.done : $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$*
	@touch $@

$(ROOT)/test_import.done: $(ROOT)/%.done : $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$*
	@touch $@

$(ROOT)/tlsstack.done: $(ROOT)/%.done : $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$*
	@touch $@

$(ROOT)/join_detach.done: $(ROOT)/%.done : $(ROOT)/%$(DOTEXE)
	@echo Testing $* is currently disabled!

$(ROOT)/%$(DOTEXE): $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

clean:
	rm -rf $(GENERATED)
