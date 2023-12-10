include ../common.mak

.PHONY: all clean

ifeq (windows,$(OS))

CC:=cl
EXTRA_CXXFLAGS:=/nologo /EHsc
EXTRA_DFLAGS:=

TESTS:=allocator array memory new string utility vector

MSC_VER:=$(strip $(shell $(CC) /nologo /EP msc_ver.c))
ifeq ($(shell test $(MSC_VER) -gt 1900; echo $$?),0)
    EXTRA_CXXFLAGS+=/std:c++17
    EXTRA_DFLAGS+=-extern-std=c++17
    TESTS+=string_view
endif

all: $(addprefix $(ROOT)/,$(TESTS))

$(ROOT)/%: $(SRC)/%.cpp $(SRC)/%_test.d
	@echo Testing $*
	@mkdir -p $(dir $@)

	$(QUIET)$(CC) /MT $(EXTRA_CXXFLAGS) -c /Fo$@_cpp$(DOTOBJ) $<
	$(QUIET)$(DMD) -mscrtlib=libcmt $(DFLAGS) $(EXTRA_DFLAGS) -main -unittest -version=CoreUnittest -version=_MSC_VER_$(MSC_VER) -of$@$(DOTEXE) $@_cpp$(DOTOBJ) $(SRC)/$*_test.d
	$(QUIET)$(TIMELIMIT)$@ $(RUN_ARGS)

	$(QUIET)$(CC) /MD $(EXTRA_CXXFLAGS) -c /Fo$@_cpp$(DOTOBJ) $<
	$(QUIET)$(DMD) -mscrtlib=msvcrt $(DFLAGS) $(EXTRA_DFLAGS) -main -unittest -version=CoreUnittest -version=_MSC_VER_$(MSC_VER) -of$@$(DOTEXE) $@_cpp$(DOTOBJ) $(SRC)/$*_test.d
	$(QUIET)$(TIMELIMIT)$@ $(RUN_ARGS)

	$(QUIET)$(CC) /MTd $(EXTRA_CXXFLAGS) -c /Fo$@_cpp$(DOTOBJ) $<
	$(QUIET)$(DMD) -mscrtlib=libcmtd $(DFLAGS) $(EXTRA_DFLAGS) -main -unittest -version=CoreUnittest -version=_MSC_VER_$(MSC_VER) -of$@$(DOTEXE) $@_cpp$(DOTOBJ) $(SRC)/$*_test.d
	$(QUIET)$(TIMELIMIT)$@ $(RUN_ARGS)

	$(QUIET)$(CC) /MDd $(EXTRA_CXXFLAGS) -c /Fo$@_cpp$(DOTOBJ) $<
	$(QUIET)$(DMD) -mscrtlib=msvcrtd $(DFLAGS) $(EXTRA_DFLAGS) -main -unittest -version=CoreUnittest -version=_MSC_VER_$(MSC_VER) -of$@$(DOTEXE) $@_cpp$(DOTOBJ) $(SRC)/$*_test.d
	$(QUIET)$(TIMELIMIT)$@ $(RUN_ARGS)

else # Posix:

HASCPP17:=`echo wow | $(CXX) -std=c++17 -E -xc++ - > /dev/null 2>&1 && echo yes`

TESTS:=allocator new utility
TESTS11:=array
TESTS17:=string_view
OLDABITESTS:=

ifeq (osx,$(OS))
    TESTS11+=memory
#   TESTS+=string
#   TESTS+=vector
endif
ifeq (linux,$(OS))
    TESTS11+=exception typeinfo
    TESTS+=typeinfo
#   TESTS+=string
#   TESTS+=vector
    OLDABITESTS+=string
endif
ifeq (freebsd,$(OS))
    TESTS11+=memory
    TESTS+=string
#   TESTS+=vector
endif

# some build machines have ancient compilers, so we need to disable C++17 tests
ifneq (yes,$(HASCPP17))
    TESTS17:=
endif

all: $(addprefix $(ROOT)/,$(addsuffix .done,$(TESTS))) $(addprefix $(ROOT)/,$(addsuffix _11.done,$(TESTS11))) $(addprefix $(ROOT)/,$(addsuffix _17.done,$(TESTS17))) $(addprefix $(ROOT)/,$(addsuffix _old.done,$(OLDABITESTS)))

# run C++98 tests
$(ROOT)/%.done: $(ROOT)/%$(DOTEXE)
	@echo Testing $*
	$(QUIET)$(TIMELIMIT)$(ROOT)/$* $(RUN_ARGS)
	@touch $@
# run C++11 tests
$(ROOT)/%_11.done: $(ROOT)/%_11$(DOTEXE)
	@echo Testing $*_11
	$(QUIET)$(TIMELIMIT)$(ROOT)/$*_11 $(RUN_ARGS)
	@touch $@
# run C++17 tests
$(ROOT)/%_17.done: $(ROOT)/%_17$(DOTEXE)
	@echo Testing $*_17
	$(QUIET)$(TIMELIMIT)$(ROOT)/$*_17 $(RUN_ARGS)
	@touch $@
# run libstdc++ _GLIBCXX_USE_CXX11_ABI=0 tests
$(ROOT)/%_old.done: $(ROOT)/%_old$(DOTEXE)
	@echo Testing $*_old
	$(QUIET)$(TIMELIMIT)$(ROOT)/$*_old $(RUN_ARGS)
	@touch $@

# build C++98 tests
$(ROOT)/%$(DOTEXE): $(SRC)/%.cpp $(SRC)/%_test.d
	@mkdir -p $(dir $@)
	$(QUIET)$(DMD) $(DFLAGS) -extern-std=c++98 -main -unittest -version=CoreUnittest -c -of=$(ROOT)/$*_d$(DOTOBJ) $(SRC)/$*_test.d
	$(QUIET)$(CXX) $(CXXFLAGS_BASE) -std=c++98 -o $@ $< $(ROOT)/$*_d$(DOTOBJ) $(DRUNTIME) -lpthread $(LDL)
# build C++11 tests
$(ROOT)/%_11$(DOTEXE): $(SRC)/%.cpp $(SRC)/%_test.d
	@mkdir -p $(dir $@)
	$(QUIET)$(DMD) $(DFLAGS) -extern-std=c++11 -main -unittest -version=CoreUnittest -c -of=$(ROOT)/$*_11_d$(DOTOBJ) $(SRC)/$*_test.d
	$(QUIET)$(CXX) $(CXXFLAGS_BASE) -std=c++11 -o $@ $< $(ROOT)/$*_11_d$(DOTOBJ) $(DRUNTIME) -lpthread $(LDL)
# build C++17 tests
$(ROOT)/%_17$(DOTEXE): $(SRC)/%.cpp $(SRC)/%_test.d
	@mkdir -p $(dir $@)
	$(QUIET)$(DMD) $(DFLAGS) -extern-std=c++17 -main -unittest -version=CoreUnittest -c -of=$(ROOT)/$*_17_d$(DOTOBJ) $(SRC)/$*_test.d
	$(QUIET)$(CXX) $(CXXFLAGS_BASE) -std=c++17 -o $@ $< $(ROOT)/$*_17_d$(DOTOBJ) $(DRUNTIME) -lpthread $(LDL)
# build libstdc++ _GLIBCXX_USE_CXX11_ABI=0 tests
$(ROOT)/%_old$(DOTEXE): $(SRC)/%.cpp $(SRC)/%_test.d
	@mkdir -p $(dir $@)
	$(QUIET)$(DMD) $(DFLAGS) -version=_GLIBCXX_USE_CXX98_ABI -main -unittest -version=CoreUnittest -c -of=$(ROOT)/$*_old_d$(DOTOBJ) $(SRC)/$*_test.d
	$(QUIET)$(CXX) $(CXXFLAGS_BASE) -D_GLIBCXX_USE_CXX11_ABI=0 -o $@ $< $(ROOT)/$*_old_d$(DOTOBJ) $(DRUNTIME) -lpthread $(LDL)

endif # end Posix

clean:
	rm -rf $(GENERATED)
