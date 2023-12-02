INSTALL_DIR=$(PWD)/../install
ECTAGS_LANGS = Make,C,C++,D,Sh
ECTAGS_FILES = compiler/dmd/*.[chd] compiler/dmd/backend/*.[chd] compiler/dmd/root/*.[chd]

GENERATED = generated
HOST_DMD?=dmd

.PHONY: all clean test install auto-tester-build auto-tester-test toolchain-info

all: $(GENERATED)/build
	$(GENERATED)/build dmd
	$(QUIET)$(MAKE) -C druntime -f posix.mak target

$(GENERATED)/build: compiler/src/build.d
	$(HOST_DMD) -of$@ -g $<

auto-tester-build:
	echo "Auto-Tester has been disabled"

auto-tester-test:
	echo "Auto-Tester has been disabled"

buildkite-test: test

toolchain-info: $(GENERATED)/build
	$(GENERATED)/build $@

clean:
	rm -Rf $(GENERATED)
	$(QUIET)$(MAKE) -C compiler/test -f Makefile clean
	$(RM) tags

test: $(GENERATED)/build
	$(GENERATED)/build unittest
	$(GENERATED)/build dmd
	$(QUIET)$(MAKE) -C compiler/test -f Makefile

html: $(GENERATED)/build
	$(GENERATED)/build $@

# Creates Exuberant Ctags tags file
tags: posix.mak $(ECTAGS_FILES)
	ctags --sort=yes --links=no --excmd=number --languages=$(ECTAGS_LANGS) \
		--langmap='C++:+.c,C++:+.h' --extra=+f --file-scope=yes --fields=afikmsSt --totals=yes posix.mak $(ECTAGS_FILES)

ifneq (,$(findstring Darwin_64_32, $(PWD)))
install:
	echo "Darwin_64_32_disabled"
else
install: all $(GENERATED)/build
	$(GENERATED)/build man
	$(GENERATED)/build install INSTALL_DIR=$(INSTALL_DIR)
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

style: $(GENERATED)/build
	$(GENERATED)/build $@

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)

# Dont run targets in parallel because this makefile is just a thin wrapper
# for build.d and multiple invocations might stomp on each other.
# (build.d employs it's own parallelization)
.NOTPARALLEL:
