INSTALL_DIR=$(PWD)/../install
SYSCONFDIR="/etc/"

.PHONY: all clean test install

all:
	$(QUIET)$(MAKE) -C src -f posix.mak

clean:
	$(QUIET)$(MAKE) -C src -f posix.mak clean
	$(QUIET)$(MAKE) -C test -f Makefile clean

test:
	$(QUIET)$(MAKE) -C test -f Makefile

install: all
	$(MAKE) INSTALL_DIR=$(INSTALL_DIR) -C src -f posix.mak install
	cp -r samples $(INSTALL_DIR)
	mkdir -p $(INSTALL_DIR)/man
	cp -r docs/man/* $(INSTALL_DIR)/man/

