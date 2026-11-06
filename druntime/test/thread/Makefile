TESTS := tlsgc_sections test_import tlsstack filterthrownglobal filterthrownmethod
# join_detach is currently disabled
#TESTS += join_detach

# some .d files support Posix only
ifeq ($(OS),windows)
    TESTS += winfiber
else
    TESTS += fiber_guard_page external_threads fiber_fpreg_gc_scan
endif

include ../common.mak

# no-op on other architectures; the asm helpers live in a separate .S file
$(ROOT)/fiber_fpreg_gc_scan$(DOTEXE): private extra_sources = $(ROOT)/fiber_gc_scan_asm$(DOTOBJ)
$(ROOT)/fiber_fpreg_gc_scan$(DOTEXE): $(ROOT)/fiber_gc_scan_asm$(DOTOBJ)

$(ROOT)/fiber_gc_scan_asm$(DOTOBJ): $(SRC)/fiber_gc_scan_asm.S | $(OBJDIR)
	$(COMPILE.c) $(OUTPUT_OPTION) $<

# segfault || bus error (OSX)
$(ROOT)/fiber_guard_page.done: $(ROOT)/%.done : $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(TIMELIMIT)$<; rc=$$?; [ $$rc -eq 139 ] || [ $$rc -eq 138 ]
	@touch $@
