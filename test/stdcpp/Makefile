include ../common.mak

TESTS:=allocator new
TESTS11:=array
TESTS14:=
TESTS17:=
OLDABITESTS:=

ifeq (osx,$(OS))
#	TESTS+=string
#	TESTS14+=string_view
endif
ifeq (linux,$(OS))
#	TESTS+=string
#	OLDABITESTS+=string
#	TESTS14+=string_view
endif
ifeq (freebsd,$(OS))
#	TESTS+=string
#	TESTS14+=string_view
endif

.PHONY: all clean

# osx32 does not link properly, nobody uses it anyway...
ifeq ($(OS)$(MODEL), osx32)

all:

clean:

else
all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS))) $(addprefix $(ROOT)/,$(addsuffix _11.done,$(TESTS11))) $(addprefix $(ROOT)/,$(addsuffix _14.done,$(TESTS14))) $(addprefix $(ROOT)/,$(addsuffix _17.done,$(TESTS17))) $(addprefix $(ROOT)/,$(addsuffix _old.done,$(OLDABITESTS)))

# run C++98 tests
$(ROOT)/%.done : $(ROOT)/%
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS)
	@touch $@
# run C++11 tests
$(ROOT)/%_11.done : $(ROOT)/%_11
	@echo Testing $*_11
	$(QUIET)$(TIMELIMIT)$(ROOT)/$*_11 $(RUN_ARGS)
	@touch $@
# run C++14 tests
$(ROOT)/%_14.done : $(ROOT)/%_14
	@echo Testing $*_14
	$(QUIET)$(TIMELIMIT)$(ROOT)/$*_14 $(RUN_ARGS)
	@touch $@
# run C++17 tests
$(ROOT)/%_17.done : $(ROOT)/%_17
	@echo Testing $*_17
	$(QUIET)$(TIMELIMIT)$(ROOT)/$*_17 $(RUN_ARGS)
	@touch $@
# run libstdc++ _GLIBCXX_USE_CXX11_ABI=0 tests
$(ROOT)/%_old.done : $(ROOT)/%_old
	@echo Testing $*_old
	$(QUIET)$(TIMELIMIT)$(ROOT)/$*_old $(RUN_ARGS)
	@touch $@

# build C++98 tests
$(ROOT)/%: $(SRC)/%.cpp $(SRC)/%_test.d
	mkdir -p $(dir $@)
	$(QUIET)$(DMD) $(DFLAGS) -extern-std=c++98 -main -unittest -c -of=$(ROOT)/$*_d.o $(SRC)/$*_test.d
	$(QUIET)$(CXX) $(CXXFLAGS_BASE) -std=c++98 -o $@ $< $(ROOT)/$*_d.o $(DRUNTIME) -lpthread
# build C++11 tests
$(ROOT)/%_11: $(SRC)/%.cpp $(SRC)/%_test.d
	mkdir -p $(dir $@)
	$(QUIET)$(DMD) $(DFLAGS) -extern-std=c++11 -main -unittest -c -of=$(ROOT)/$*_11_d.o $(SRC)/$*_test.d
	$(QUIET)$(CXX) $(CXXFLAGS_BASE) -std=c++11 -o $@ $< $(ROOT)/$*_11_d.o $(DRUNTIME) -lpthread
# build C++14 tests
$(ROOT)/%_14: $(SRC)/%.cpp $(SRC)/%_test.d
	mkdir -p $(dir $@)
	$(QUIET)$(DMD) $(DFLAGS) -extern-std=c++14 -main -unittest -c -of=$(ROOT)/$*_14_d.o $(SRC)/$*_test.d
	$(QUIET)$(CXX) $(CXXFLAGS_BASE) -std=c++14 -o $@ $< $(ROOT)/$*_14_d.o $(DRUNTIME) -lpthread
# build C++17 tests
$(ROOT)/%_17: $(SRC)/%.cpp $(SRC)/%_test.d
	mkdir -p $(dir $@)
	$(QUIET)$(DMD) $(DFLAGS) -extern-std=c++17 -main -unittest -c -of=$(ROOT)/$*_17_d.o $(SRC)/$*_test.d
	$(QUIET)$(CXX) $(CXXFLAGS_BASE) -std=c++17 -o $@ $< $(ROOT)/$*_17_d.o $(DRUNTIME) -lpthread
# build libstdc++ _GLIBCXX_USE_CXX11_ABI=0 tests
$(ROOT)/%_old: $(SRC)/%.cpp $(SRC)/%_test.d
	mkdir -p $(dir $@)
	$(QUIET)$(DMD) $(DFLAGS) -version=_GLIBCXX_USE_CXX98_ABI -main -unittest -c -of=$(ROOT)/$*_old_d.o $(SRC)/$*_test.d
	$(QUIET)$(CXX) $(CXXFLAGS_BASE) -D_GLIBCXX_USE_CXX11_ABI=0 -o $@ $< $(ROOT)/$*_old_d.o $(DRUNTIME) -lpthread

clean:
	rm -rf $(GENERATED)
endif
