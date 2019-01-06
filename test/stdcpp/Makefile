include ../common.mak

TESTS:=array new

.PHONY: all clean

# osx32 does not link properly, nobody uses it anyway...
ifeq ($(OS)$(MODEL), osx32)

all:

clean:

else
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done : $(ROOT)/%
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS)
	@touch $@

$(ROOT)/%: $(SRC)/%.cpp $(SRC)/%_test.d
	mkdir -p $(dir $@)
	$(QUIET)$(DMD) $(DFLAGS) -main -unittest -c -of=$(ROOT)/$*_d.o $(SRC)/$*_test.d
	$(QUIET)$(CXX) $(CXXFLAGS) -o $@ $< $(ROOT)/$*_d.o $(DRUNTIME) -lpthread

clean:
	rm -rf $(GENERATED)
endif
