include ../common.mak

.PHONY: all clean
all: $(ROOT)/test$(DOTEXE)

$(ROOT)/%$(DOTEXE): %.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< uuid.lib

clean:
	rm -rf $(ROOT)
