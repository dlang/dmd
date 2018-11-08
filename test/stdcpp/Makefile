include ../common.mak

TESTS:=array

.PHONY: all clean
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS)))

$(ROOT)/%.done : $(ROOT)/%
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS)
	@touch $@

$(ROOT)/%: $(SRC)/%_test.d $(SRC)/%.cpp
	mkdir -p $(dir $@)
	# osx32 does not link properly, nobody uses it anyway...
	if [$(OS)$(MODEL) = "osx32"]
	$(QUIET)$(CXX) $(CXXFLAGS) -c -o $(ROOT)/$*_cpp.o $(SRC)/$*.cpp
	$(QUIET)$(DMD) $(DFLAGS) -main -unittest -of$@ $< $(ROOT)/$*_cpp.o
	fi

clean:
	rm -rf $(GENERATED)
