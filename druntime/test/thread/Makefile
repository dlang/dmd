TESTS := tlsgc_sections test_import tlsstack
# join_detach is currently disabled
#TESTS += join_detach

# some .d files support Posix only
ifneq ($(OS),windows)
    TESTS += fiber_guard_page external_threads
endif

include ../common.mak

# segfault || bus error (OSX)
$(ROOT)/fiber_guard_page.done: $(ROOT)/%.done : $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(TIMELIMIT)$<; rc=$$?; [ $$rc -eq 139 ] || [ $$rc -eq 138 ]
	@touch $@
