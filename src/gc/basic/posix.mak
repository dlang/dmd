# Makefile to build the garbage collector D library for Posix
# Designed to work with GNU make
# Targets:
#	make
#		Same as make all
#	make debug
#		Build the debug version of the library
#   make release
#       Build the release version of the library
#   make doc
#       Generate documentation
#	make clean
#		Delete all files created by build process

# Essentials

LIBDIR=../../../lib
DOCDIR=../../../doc
IMPDIR=../../../import
LIBBASENAME=libdruntime-gc-basic.a
MODULES=gc gcalloc gcbits gcstats gcx
BUILDS=debug release unittest

# Symbols

DMD=dmd
DOCFLAGS=-version=DDoc
DFLAGS_release=-d -release -O -inline -w -nofloat
DFLAGS_debug=-d -g -w -nofloat
DFLAGS_unittest=$(DFLAGS_release) -unittest
CFLAGS_release=-m32 -O
CFLAGS_debug=-m32 -g
CFLAGS_unittest=$(CFLAGS_release)

# Derived symbols

SRCS=$(addsuffix .d,$(MODULES))
DOCS=
IMPORTS=
ALLLIBS=$(addsuffix /$(LIBBASENAME),$(addprefix $(LIBDIR)/,$(BUILDS)))

# Patterns

$(LIBDIR)/%/$(LIBBASENAME) : $(SRCS)
	$(DMD) $(DFLAGS_$*) -lib -of$@ $^

$(DOCDIR)/%.html : %.d
	$(DMD) -c -d -o- -Df$@ $<

$(IMPDIR)/%.di : %.d
	$(DMD) -c -d -o- -Hf$@ $<

# Rulez

all : $(BUILDS) doc

debug : $(LIBDIR)/debug/$(LIBBASENAME) $(IMPORTS)
release : $(LIBDIR)/release/$(LIBBASENAME) $(IMPORTS)
unittest : $(LIBDIR)/unittest/$(LIBBASENAME) $(IMPORTS)
#doc : $(DOCS)

clean :
	rm -f $(IMPORTS) $(DOCS) $(ALLLIBS)
