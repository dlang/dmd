INSTALL_DIR=$(PWD)/../install
ECTAGS_LANGS = Make,C,C++,D,Sh
ECTAGS_FILES = src/dmd/*.[chd] src/dmd/backend/*.[chd] src/dmd/root/*.[chd]

.PHONY: all clean test install auto-tester-build auto-tester-test toolchain-info

all:
	$(QUIET)$(MAKE) -C src -f posix.mak all

ifneq (,$(findstring Darwin_64_32, $(PWD)))
auto-tester-build:
	echo "Darwin_64_32_disabled"
else
auto-tester-build:
	$(QUIET)$(MAKE) -C src -f posix.mak auto-tester-build ENABLE_RELEASE=1 ENABLE_ASSERTS=1
endif

ifneq (,$(findstring Darwin_64_32, $(PWD)))
auto-tester-test:
	echo "Darwin_64_32_disabled"
else
ifneq (,$(findstring windows, $(PWD)))
auto-tester-test: test
else # POSIX
# Like test, but without runnable_cxx
auto-tester-test:
	$(QUIET)$(MAKE) -C src -f posix.mak auto-tester-test
	$(QUIET)$(MAKE) -C test -f Makefile auto-tester-test
endif
endif

buildkite-test: test

toolchain-info:
	$(QUIET)$(MAKE) -C src -f posix.mak toolchain-info

clean:
	$(QUIET)$(MAKE) -C src -f posix.mak clean
	$(QUIET)$(MAKE) -C test -f Makefile clean
	$(RM) tags

test:
	$(QUIET)$(MAKE) -C src -f posix.mak unittest
	$(QUIET)$(MAKE) -C src -f posix.mak dmd
	$(QUIET)$(MAKE) -C test -f Makefile

html:
	$(QUIET)$(MAKE) -C src -f posix.mak html

# Creates Exuberant Ctags tags file
tags: posix.mak $(ECTAGS_FILES)
	ctags --sort=yes --links=no --excmd=number --languages=$(ECTAGS_LANGS) \
		--langmap='C++:+.c,C++:+.h' --extra=+f --file-scope=yes --fields=afikmsSt --totals=yes posix.mak $(ECTAGS_FILES)

ifneq (,$(findstring Darwin_64_32, $(PWD)))
install:
	echo "Darwin_64_32_disabled"
else
install: all
	$(MAKE) INSTALL_DIR=$(INSTALL_DIR) -C src -f posix.mak install
	cp -r samples $(INSTALL_DIR)
	mkdir -p $(INSTALL_DIR)/man
	cp -r docs/man/* $(INSTALL_DIR)/man/
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

style:
	$(QUIET)$(MAKE) -C src -f posix.mak style

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)

# Dont run targets in parallel because this makefile is just a thin wrapper
# for build.d and multiple invocations might stomp on each other.
# (build.d employs it's own parallelization)
.NOTPARALLEL:
