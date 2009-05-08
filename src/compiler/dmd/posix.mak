# Makefile to build the compiler runtime D library for Linux
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
LIBBASENAME=libdruntime-rt-dmd.a
MODULES=
BUILDS=debug release unittest

MODULES_BASE=aaA aApply aApplyR adi alloca arrayassign arraybyte	\
    arraycast arraycat arraydouble arrayfloat arrayint arrayreal	\
    arrayshort cast_ cmath2 cover deh2 dmain2 invariant invariant_	\
    lifetime llmath memory memset obj object_ qsort switch_ trace
# NOTE: trace.o and cover.o are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for Linux
# NOTE: deh.o is only needed for Win32, Linux uses deh2.o
MODULES_UTIL=$(addprefix util/,console cpuid ctype string utf)
MODULES_TI=$(addprefix typeinfo/ti_,AC Acdouble Acfloat Acreal Adouble	\
    Afloat Ag Aint Along Areal Ashort byte C cdouble cfloat char creal	\
    dchar delegate double float idouble ifloat int ireal long ptr real	\
    short ubyte uint ulong ushort void wchar)
C_SRCS=complex.c critical.c memory_osx.c monitor.c

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

C_OBJS=$(addsuffix .o,$(basename $(C_SRCS)))
AS_OBJS=$(addsuffix .o,$(basename $(AS_SRCS)))
ALL_MODULES=$(MODULES_BASE) $(MODULES_UTIL) $(MODULES_TI)
D_SRCS=$(addsuffix .d,$(ALL_MODULES))
ALLLIBS=$(addsuffix /$(LIBBASENAME),$(addprefix $(LIBDIR)/,$(BUILDS)))

# Patterns

$(LIBDIR)/%/$(LIBBASENAME) : $(D_SRCS) $(C_SRCS) $(AS_SRCS)
	$(CC) -c $(CFLAGS_$*) $(C_SRCS)
	$(DMD) $(DFLAGS_$*) -lib -of$@ $(D_SRCS) $(C_OBJS) $(AS_OBJS)
	rm $(C_OBJS) $(AS_OBJS)

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
