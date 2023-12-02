# Proxy Makefile for backwards compatibility after move to /compiler/src


all:
	$(QUIET)$(MAKE) -C .. -f posix.mak $@

buildkite-test:
	$(QUIET)$(MAKE) -C .. -f posix.mak $@

toolchain-info:
	$(QUIET)$(MAKE) -C .. -f posix.mak $@

clean:
	$(QUIET)$(MAKE) -C .. -f posix.mak $@

test:
	$(QUIET)$(MAKE) -C .. -f posix.mak $@

html:
	$(QUIET)$(MAKE) -C .. -f posix.mak $@

tags:
	$(QUIET)$(MAKE) -C .. -f posix.mak $@

install:
	$(QUIET)$(MAKE) -C .. -f posix.mak $@

check-clean-git:
	$(QUIET)$(MAKE) -C .. -f posix.mak $@

style:
	$(QUIET)$(MAKE) -C .. -f posix.mak $@
