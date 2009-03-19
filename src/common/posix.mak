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
IMPDIR=../../import
LIBBASENAME=libdruntime-core.a
MODULES=bitop exception memory runtime thread vararg \
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

C_SRCS=core/stdc/c_errno.c core/threadasm.S
C_OBJS=errno.o threadasm.o
AS_OBJS=$(addsuffix .o,$(basename $(AS_SRCS)))
D_SRCS=$(addsuffix .d,$(addprefix core/,$(MODULES))) \
	$(addsuffix .d,$(addprefix $(IMPDIR)/core/stdc/,errno math stdarg stdio wchar_))
DOCS=$(addsuffix .html,$(addprefix $(DOCDIR)/core/,$(MODULES)))
IMPORTS=$(addsuffix .di,$(addprefix $(IMPDIR)/core/,$(MODULES)))
ALLLIBS=$(addsuffix /$(LIBBASENAME),$(addprefix $(LIBDIR)/,$(BUILDS)))

# Patterns

$(LIBDIR)/%/$(LIBBASENAME) : $(D_SRCS) $(C_SRCS)
	$(CC) -c $(CFLAGS_$*) $(C_SRCS)
	$(DMD) $(DFLAGS_$*) -lib -of$@ $(D_SRCS) $(C_OBJS)
	rm $(C_OBJS)

$(DOCDIR)/%.html : %.d
	$(DMD) -c -d -o- -Df$@ $<

$(IMPDIR)/%.di : %.d
	$(DMD) -c -d -o- -Hf$@ $<

# Rulez

all : $(BUILDS) doc

debug : $(LIBDIR)/debug/$(LIBBASENAME) $(IMPORTS)
release : $(LIBDIR)/release/$(LIBBASENAME) $(IMPORTS)
unittest : $(LIBDIR)/unittest/$(LIBBASENAME) $(IMPORTS)
doc : $(DOCS)

clean :
	rm -f $(IMPORTS) $(DOCS) $(ALLLIBS)
