INSTALL_DIR=$(PWD)/../install
ECTAGS_LANGS = Make,C,C++,D,Sh
ECTAGS_FILES = src/*.[chd] src/backend/*.[chd] src/root/*.[chd] src/tk/*.[chd]

UNAME:= $(shell uname -s)
JOBS=1
ifeq ($(UNAME), Darwin)
	JOBS=$(shell sysctl -n hw.ncpu)
endif
ifeq ($(UNAME), Linux)
	JOBS=$(shell nproc)
endif

.PHONY: all clean test install auto-tester-build auto-tester-test toolchain-info

all:
	$(QUIET)$(MAKE) -C src -f posix.mak all

auto-tester-build: toolchain-info
	$(QUIET)$(MAKE) -C src -f posix.mak auto-tester-build ENABLE_RELEASE=1

auto-tester-test: test

toolchain-info:
	$(QUIET)$(MAKE) -C src -f posix.mak toolchain-info

clean:
	$(QUIET)$(MAKE) -C src -f posix.mak clean
	$(QUIET)$(MAKE) -C test -f Makefile clean
	$(RM) tags

test:
	$(QUIET)$(MAKE) -C src -f posix.mak build-examples
	$(QUIET)$(MAKE) -C src -f posix.mak unittest
	$(QUIET)$(MAKE) -C test -f Makefile -j$(JOBS)

html:
	$(QUIET)$(MAKE) -C src -f posix.mak html

# Creates Exuberant Ctags tags file
tags: posix.mak $(ECTAGS_FILES)
	ctags --sort=yes --links=no --excmd=number --languages=$(ECTAGS_LANGS) \
		--langmap='C++:+.c,C++:+.h' --extra=+f --file-scope=yes --fields=afikmsSt --totals=yes posix.mak $(ECTAGS_FILES)

install: all
	$(MAKE) INSTALL_DIR=$(INSTALL_DIR) -C src -f posix.mak install
	cp -r samples $(INSTALL_DIR)
	mkdir -p $(INSTALL_DIR)/man
	cp -r docs/man/* $(INSTALL_DIR)/man/

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
	@echo "To be done"

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)
