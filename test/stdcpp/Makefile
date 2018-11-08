include ../common.mak

TESTS:=array

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

# osx32 does not link properly, nobody uses it anyway...
ifneq ($(OS)$(MODEL), osx32)
$(ROOT)/%.done : $(ROOT)/%
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS)
	@touch $@

$(ROOT)/%: $(SRC)/%_test.d $(SRC)/%.cpp
	mkdir -p $(dir $@)
	$(QUIET)$(CXX) $(CXXFLAGS) -c -o $(ROOT)/$*_cpp.o $(SRC)/$*.cpp
	$(QUIET)$(DMD) $(DFLAGS) -main -unittest -of$@ $< $(ROOT)/$*_cpp.o
endif

clean:
	rm -rf $(GENERATED)
