# Makefile to build the garbage collector D library for Posix
# Designed to work with GNU make
# Targets:
#       make
#               Same as make all
#       make debug
#               Build the debug version of the library
#   make release
#       Build the release version of the library
#   make doc
#       Generate documentation
#       make clean
#               Delete all files created by build process

# Essentials

LIBDIR=../../../lib
DOCDIR=../../../doc
LIBBASENAME=libdruntime-gc-stub
MODULES=gc
BUILDS=debug release unittest
GENDIR=generated

# Symbols

CFLAGS_release=-O
CFLAGS_debug=-g
CFLAGS_unittest=$(CFLAGS_release)

DFLAGS_release=-release -O -inline -w -nofloat
DFLAGS_debug=-g -w -nofloat
DFLAGS_unittest=$(DFLAGS_release) -unittest

DMD=dmd

# Derived symbols

SRCS=$(addsuffix .d,$(MODULES))
OBJS=$(addprefix $(GENDIR)/,$(addsuffix .o,$(MODULES)))
ALLLIBS=$(addsuffix /$(LIBBASENAME),$(addprefix $(LIBDIR)/,$(BUILDS)))

######################################################

$(LIBDIR)/%/$(LIBBASENAME).a : $(SRCS)
        $(foreach f,$^,$(DMD) $(DFLAGS_$*) -c $f -od$(GENDIR) &&) true
        $(DMD) $(DFLAGS_$*) -lib -of$@ $(OBJS)
        rm -rf $(GENDIR)

%.o : %.d
        $(CC) -c $(CFLAGS) $< -o $@

######################################################

all : debug release unittest
debug : $(LIBDIR)/debug/$(LIBBASENAME).a
release : $(LIBDIR)/release/$(LIBBASENAME).a
unittest : $(LIBDIR)/unittest/$(LIBBASENAME).a

doc :
        @echo No documentation for $(LIBBASENAME).

clean :
        rm -rf $(GENDIR) 
        rm -f $(ALLLIBS) 

