# Proxy Makefile for backwards compatibility after move to /compiler/src


all:
	$(QUIET)$(MAKE) -C .. $@

buildkite-test:
	$(QUIET)$(MAKE) -C .. $@

toolchain-info:
	$(QUIET)$(MAKE) -C .. $@

clean:
	$(QUIET)$(MAKE) -C .. $@

test:
	$(QUIET)$(MAKE) -C .. $@

html:
	$(QUIET)$(MAKE) -C .. $@

tags:
	$(QUIET)$(MAKE) -C .. $@

install:
	$(QUIET)$(MAKE) -C .. $@

check-clean-git:
	$(QUIET)$(MAKE) -C .. $@

style:
	$(QUIET)$(MAKE) -C .. $@
