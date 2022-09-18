# Proxy Makefile for backwards compatibility after move to /compiler/src


all:
	$(QUIET)$(MAKE) -C ../compiler/src -f posix.mak $@

auto-tester-build:
	$(QUIET)$(MAKE) -C ../compiler/src -f posix.mak $@

auto-tester-test:
	$(QUIET)$(MAKE) -C ../compiler/src -f posix.mak $@

buildkite-test:
	$(QUIET)$(MAKE) -C ../compiler/src -f posix.mak $@

toolchain-info:
	$(QUIET)$(MAKE) -C ../compiler/src -f posix.mak $@

clean:
	$(QUIET)$(MAKE) -C ../compiler/src -f posix.mak $@

test:
	$(QUIET)$(MAKE) -C ../compiler/src -f posix.mak $@

html:
	$(QUIET)$(MAKE) -C ../compiler/src -f posix.mak $@

tags:
	$(QUIET)$(MAKE) -C ../compiler/src -f posix.mak $@

install:
	$(QUIET)$(MAKE) -C ../compiler/src -f posix.mak $@

check-clean-git:
	$(QUIET)$(MAKE) -C ../compiler/src -f posix.mak $@

style:
	$(QUIET)$(MAKE) -C ../compiler/src -f posix.mak $@
