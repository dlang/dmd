include compiler/src/osmodel.mak

INSTALL_DIR=$(shell pwd)/../install
ECTAGS_LANGS = Make,C,C++,D,Sh
ECTAGS_FILES = compiler/dmd/*.[chd] compiler/dmd/backend/*.[chd] compiler/dmd/root/*.[chd]

EXE=$(if $(findstring windows,$(OS)),.exe,)

ifeq (,$(HOST_DMD))
    ifneq (,$(HOST_DC))
        $(warning The HOST_DC variable is deprecated, please use HOST_DMD instead.)
        HOST_DMD:=$(HOST_DC)
    else ifneq (,$(DMD))
        HOST_DMD:=$(DMD)
    else ifneq (,$(shell which dmd))
        HOST_DMD:=dmd$(EXE)
    else ifneq (,$(shell which ldmd2))
        HOST_DMD:=ldmd2$(EXE)
    else ifneq (,$(shell which gdmd))
        HOST_DMD:=gdmd$(EXE)
    else
        $(error Couldn't find a D host compiler. Please set variable HOST_DMD to the path to a dmd/ldmd2/gdmd executable)
    endif
    $(info Using D host compiler: $(HOST_DMD))
endif
export HOST_DMD

GENERATED=generated
BUILD_EXE=$(GENERATED)/build$(EXE)
RUN_EXE=$(GENERATED)/run$(EXE)

.PHONY: all clean test html install \
        dmd dmd-test druntime druntime-test \
        auto-tester-build auto-tester-test buildkite-test \
        toolchain-info check-clean-git style

all: dmd druntime

$(BUILD_EXE): compiler/src/build.d
	$(HOST_DMD) -of$@ -g $<

$(RUN_EXE): compiler/test/run.d
	$(HOST_DMD) -of$@ -g -i -Icompiler/test -release $<

auto-tester-build:
	echo "Auto-Tester has been disabled"

auto-tester-test:
	echo "Auto-Tester has been disabled"

buildkite-test: test

toolchain-info: $(BUILD_EXE)
	$(BUILD_EXE) $@

clean:
	rm -rf $(GENERATED)
	cd compiler/test && rm -rf test_results *.lst trace.log trace.def
	$(RM) tags
ifneq (windows,$(OS))
	$(QUIET)$(MAKE) -C druntime -f posix.mak clean
endif

dmd: $(BUILD_EXE)
	$(BUILD_EXE) $@

dmd-test: dmd druntime $(BUILD_EXE) $(RUN_EXE)
	$(BUILD_EXE) unittest
	$(RUN_EXE) --environment

druntime: dmd
ifeq (windows,$(OS))
	@echo "Building druntime via top-level Makefile on Windows will come soon"
else
	$(QUIET)$(MAKE) -C druntime -f posix.mak
endif

druntime-test: dmd
ifeq (windows,$(OS))
	@echo "Testing druntime via top-level Makefile on Windows will come soon"
else
	$(QUIET)$(MAKE) -C druntime -f posix.mak unittest
endif

test: dmd-test druntime-test

html: $(BUILD_EXE)
	$(BUILD_EXE) $@

# Creates Exuberant Ctags tags file
tags: Makefile $(ECTAGS_FILES)
	ctags --sort=yes --links=no --excmd=number --languages=$(ECTAGS_LANGS) \
		--langmap='C++:+.c,C++:+.h' --extra=+f --file-scope=yes --fields=afikmsSt --totals=yes Makefile $(ECTAGS_FILES)

ifneq (,$(findstring Darwin_64_32, $(PWD)))
install:
	echo "Darwin_64_32_disabled"
else
install: all $(BUILD_EXE)
	$(BUILD_EXE) man
	$(BUILD_EXE) install INSTALL_DIR=$(if $(findstring $(OS),windows),$(shell cygpath -w "$(INSTALL_DIR)"),$(INSTALL_DIR))
	cp -r compiler/samples $(INSTALL_DIR)
	mkdir -p $(INSTALL_DIR)/man
	cp -r generated/docs/man/* $(INSTALL_DIR)/man/
endif

# Checks that all files have been committed and no temporary, untracked files exist.
# See: https://github.com/dlang/dmd/pull/7483
check-clean-git:
	@if [ -n "$$(git status --porcelain)" ] ; then \
		echo "ERROR: Found the following residual temporary files."; \
		echo 'ERROR: Temporary files should be stored in `test_results` or explicitly removed.'; \
		git status -s ; \
		exit 1; \
	fi

style: $(BUILD_EXE)
	$(BUILD_EXE) $@

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)

# Dont run targets in parallel because this makefile is just a thin wrapper
# for build.d and multiple invocations might stomp on each other.
# (build.d employs it's own parallelization)
.NOTPARALLEL:
