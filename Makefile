include compiler/src/osmodel.mak

INSTALL_DIR=$(shell pwd)/../install
ECTAGS_LANGS = Make,C,C++,D,Sh
ECTAGS_FILES = compiler/dmd/*.[chd] compiler/dmd/backend/*.[chd] compiler/dmd/root/*.[chd]

EXE=$(if $(findstring windows,$(OS)),.exe,)

HOST_DMD?=$(DMD)
ifeq (,$(HOST_DMD))
    HOST_DMD=dmd$(EXE)
endif
export HOST_DMD

GENERATED=generated
BUILD_EXE=$(GENERATED)/build$(EXE)
RUN_EXE=$(GENERATED)/run$(EXE)

.PHONY: all clean test install auto-tester-build auto-tester-test toolchain-info

all: $(BUILD_EXE)
	$(BUILD_EXE) dmd
ifneq (windows,$(OS))
	$(QUIET)$(MAKE) -C druntime -f posix.mak target
endif

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

test: all $(BUILD_EXE) $(RUN_EXE)
	$(BUILD_EXE) unittest
	$(RUN_EXE) --environment
ifneq (windows,$(OS))
	$(QUIET)$(MAKE) -C druntime -f posix.mak unittest
endif

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
