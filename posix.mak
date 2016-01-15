INSTALL_DIR=$(PWD)/../install
ECTAGS_LANGS = Make,C,C++,D,Sh
ECTAGS_FILES = src/*.[chd] src/backend/*.[chd] src/root/*.[chd] src/tk/*.[chd]

.PHONY: all clean test install auto-tester-build auto-tester-test

all:
	$(QUIET)$(MAKE) -C src -f posix.mak

auto-tester-build:
	$(QUIET)$(MAKE) -C src -f posix.mak auto-tester-build

auto-tester-test: test

clean:
	$(QUIET)$(MAKE) -C src -f posix.mak clean
	$(QUIET)$(MAKE) -C test -f Makefile clean
	$(RM) tags

test:
	$(QUIET)$(MAKE) -C test -f Makefile

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

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)
