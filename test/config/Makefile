include ../common.mak

TESTS:=test19433

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $<

$(ROOT)/test19433.done: $(ROOT)/test19433
	@echo Testing test19433
	$(QUIET)$(ROOT)/test19433 --DRT-dont-eat-me
	@touch $@

clean:
	rm -rf $(ROOT)
