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
CFLAGS_release=-O
CFLAGS_debug=-g
CFLAGS_unittest=$(CFLAGS_release)

# Derived symbols

SRCS=$(addsuffix .d,$(addprefix core/,$(MODULES)))
DOCS=$(addsuffix .html,$(addprefix $(DOCDIR)/,$(MODULES)))
IMPORTS=$(addsuffix .di,$(addprefix $(IMPDIR)/,$(MODULES)))
ALLLIBS=$(addsuffix /$(LIBBASENAME),$(addprefix $(LIBDIR)/,$(BUILDS)))

# Patterns

$(LIBDIR)/%/$(LIBBASENAME) : $(SRCS) $(LIBDIR)/%/errno.o
	$(DMD) $(DFLAGS_$*) -lib -of$@ $^

$(LIBDIR)/%/errno.o : core/stdc/errno.c
	@mkdir --parents $(dir $@)
	$(CC) -c $(CFLAGS_$*) $< -o$@

# Rulez

all : $(BUILDS) doc

debug : $(LIBDIR)/debug/$(LIBBASENAME) $(IMPORTS)
release : $(LIBDIR)/release/$(LIBBASENAME) $(IMPORTS)
unittest : $(LIBDIR)/unittest/$(LIBBASENAME) $(IMPORTS)
doc : $(DOCS)

$(DOCS) : $(SRCS)
	$(DMD) -c -d -o- $(DOCFLAGS) -Df$@ $?

$(IMPORTS) : $(SRCS)
	$(DMD) -c -d -o- -Hf$@ $?

clean :
	rm -f $(IMPORTS) $(DOCS) $(ALLLIBS)

