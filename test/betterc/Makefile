include ../common.mak

TESTS:=test18828

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix ,$(TESTS)))

$(ROOT)/%: $(SRC)/%.d
	$(QUIET)$(DMD) -betterC -c -of$@ $<

clean:
	rm -rf $(ROOT)
