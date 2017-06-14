.PHONY: all

all: src/dmd

src/dmd:
	$(MAKE) -C src -f posix.mak

$O/pkg-dmd1.stamp: src/dmd
