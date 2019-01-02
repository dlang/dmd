include ../common.mak

TESTS := sentinel printf memstomp invariant logging

SRC_GC = ../../src/gc/impl/conservative/gc.d
SRC = $(SRC_GC) ../../src/rt/lifetime.d
# ../../src/object.d causes duplicate symbols
UDFLAGS = $(DFLAGS) -unittest -main

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done: $(ROOT)/%
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS)
	@touch $@

$(ROOT)/sentinel: $(SRC)
	$(DMD) -debug=SENTINEL $(UDFLAGS) -of$@ $(SRC)

$(ROOT)/printf: $(SRC)
	$(DMD) -debug=PRINTF -debug=PRINTF_TO_FILE -debug=COLLECT_PRINTF $(UDFLAGS) -of$@ $(SRC_GC)

$(ROOT)/memstomp: $(SRC)
	$(DMD) -debug=MEMSTOMP $(UDFLAGS) -of$@ $(SRC)

$(ROOT)/invariant: $(SRC)
	$(DMD) -debug -debug=INVARIANT -debug=PTRCHECK -debug=PTRCHECK2 $(UDFLAGS) -of$@ $(SRC)

$(ROOT)/logging: $(SRC)
	$(DMD) -debug=LOGGING $(UDFLAGS) -of$@ $(SRC)

clean:
	rm -rf $(ROOT)
