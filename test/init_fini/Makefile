include ../common.mak

TESTS:=thread_join runtime_args test18996 custom_gc

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS)
	@touch $@

$(ROOT)/custom_gc: $(ROOT)/register_custom_gc.o
$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $^

$(ROOT)/register_custom_gc.o: $(SRC)/register_custom_gc.c
	$(QUIET)$(CC) -c $(CFLAGS) -o $@ $^

clean:
	rm -rf $(ROOT)
