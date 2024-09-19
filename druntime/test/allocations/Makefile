TESTS := overflow_from_zero overflow_from_existing alloc_from_assert

include ../common.mak

$(OBJDIR)/alloc_from_assert.done: $(OBJDIR)/alloc_from_assert$(DOTEXE)
	@echo Testing $(<F:$(DOTEXE)=)
	$(TIMELIMIT)$<
	@touch $@

$(OBJDIR)/overflow_from_zero.done: stderr_exp="Memory allocation failed"
$(OBJDIR)/overflow_from_existing.done: stderr_exp="Memory allocation failed"
$(OBJDIR)/%.done: $(OBJDIR)/%$(DOTEXE)
	@echo Testing $*
	$(TIMELIMIT)$< 2>&1 1>/dev/null | head -n 2 | grep -qF $(stderr_exp)
	@touch $@
