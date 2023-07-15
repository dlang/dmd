include ../common.mak

TESTS := ok_append no_use_after_free no_oob no_oob_sentinel no_use_after_gc

GC_SRC = \
  ../../src/core/internal/gc/impl/conservative/gc.d \
  ../../src/etc/valgrind/valgrind.d \
  ../../src/rt/lifetime.d

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/ok_%.done: $(ROOT)/ok_%
	@echo Testing ok_$*
	$(QUIET)if ! command -v valgrind >/dev/null; then \
		echo valgrind not installed, skipping; \
	else \
		$(TIMELIMIT)valgrind --quiet --tool=memcheck --error-exitcode=8 $(ROOT)/ok_$* $(RUN_ARGS); \
	fi
	$(QUIET)touch $@

$(ROOT)/no_%.done: $(ROOT)/no_%
	@echo Testing no_$*
	$(QUIET)if ! command -v valgrind >/dev/null; then \
		echo valgrind not installed, skipping; \
	else \
		( ! $(TIMELIMIT)valgrind --quiet --tool=memcheck --error-exitcode=8 $(ROOT)/no_$* $(RUN_ARGS); ) \
	fi
	$(QUIET)touch $@

$(ROOT)/%: $(SRC)/%.d $(GC_SRC)
	$(QUIET)$(DMD) -debug=VALGRIND -debug=SENTINEL $(DFLAGS) -of$@ $< $(GC_SRC)
clean:
	rm -rf $(ROOT)
