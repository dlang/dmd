VALGRIND = valgrind
has_valgrind != command -v $(VALGRIND) > /dev/null 2>&1 && echo 1

ifeq ($(has_valgrind),1)
TESTS := ok_append no_use_after_free no_oob no_oob_sentinel no_use_after_gc
endif

include ../common.mak

$(OBJDIR)/ok_%.done: private negate :=
$(OBJDIR)/no_%.done: private negate := !

$(OBJDIR)/%.done: $(OBJDIR)/%$(DOTEXE)
	@echo Testing $<
	$(negate) $(TIMELIMIT)$(VALGRIND) --quiet --tool=memcheck --error-exitcode=8 $<
	@touch $@

gc_src := \
  ../../src/core/internal/gc/impl/conservative/gc.d \
  ../../src/etc/valgrind/valgrind.d \
  ../../src/rt/lifetime.d

$(OBJDIR)/%$(DOTEXE): $(gc_src)
$(OBJDIR)/%$(DOTEXE): private extra_sources += $(gc_src)
$(OBJDIR)/%$(DOTEXE): private extra_dflags += -debug=VALGRIND -debug=SENTINEL
