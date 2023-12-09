include ../common.mak

SUPPORTED:=0
ifeq (windows,$(OS))
    ifneq (32omf,$(MODEL))
        SUPPORTED:=1
    endif
endif

.PHONY: all clean

ifneq (1,$(SUPPORTED))
all:
	@echo "Skipping uuid test on platforms other than Windows MSVC"
else
all: $(ROOT)/test$(DOTEXE)

$(ROOT)/%$(DOTEXE): %.d
	$(QUIET)$(DMD) $(DFLAGS) -of$@ $< uuid.lib
endif

clean:
	rm -rf $(ROOT)
