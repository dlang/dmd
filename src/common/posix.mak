# Makefile to build the D runtime library core components for Posix
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

LIBDIR=../../lib
DOCDIR=../../doc
IMPDIR=../../import/core
LIBBASENAME=libdruntime-core.a
MODULES=bitmanip exception memory runtime thread vararg \
	$(addprefix sync/,barrier condition config exception mutex rwmutex semaphore)
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

SRCS=$(addsuffix .d,$(addprefix core/,$(MODULES))) $(IMPDIR)/stdc/stdio.d
DOCS=$(addsuffix .html,$(addprefix $(DOCDIR)/,$(MODULES)))
IMPORTS=$(addsuffix .di,$(addprefix $(IMPDIR)/,$(MODULES)))
ALLLIBS=$(addsuffix /$(LIBBASENAME),$(addprefix $(LIBDIR)/,$(BUILDS)))

# Patterns

$(LIBDIR)/%/$(LIBBASENAME) : $(SRCS) $(LIBDIR)/%/errno.o
	$(DMD) $(DFLAGS_$*) -lib -of$@ $^

$(LIBDIR)/%/errno.o : core/stdc/errno.c
	@mkdir -p $(dir $@)
	$(CC) -c $(CFLAGS_$*) $< -o$@

$(DOCDIR)/%.html : core/%.d
	$(DMD) -c -d -o- -Df$@ $<

$(IMPDIR)/%.di : core/%.d
	$(DMD) -c -d -o- -Hf$@ $<

# Rulez

all : $(BUILDS) doc

debug : $(LIBDIR)/debug/$(LIBBASENAME) $(IMPORTS)
release : $(LIBDIR)/release/$(LIBBASENAME) $(IMPORTS)
unittest : $(LIBDIR)/unittest/$(LIBBASENAME) $(IMPORTS)
doc : $(DOCS)

clean :
	rm -f $(IMPORTS) $(DOCS) $(ALLLIBS)

