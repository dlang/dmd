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
LIBBASENAME=libdruntime-rt-dmd.a
MODULES=bitmanip exception memory runtime thread vararg
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
C_SRCS=complex.c critical.c memory_osx.c monitor.c tls.S

# Symbols

DMD=dmd

CFLAGS_release=-m32 -O
CFLAGS_debug=-m32 -g
CFLAGS_unittest=$(CFLAGS_release)

DFLAGS_release=-release -O -inline -w -nofloat
DFLAGS_debug=-g -w -nofloat
DFLAGS_unittest=$(DFLAGS_release) -unittest

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

# Rulez

all : release debug unittest
release : $(LIBDIR)/release/$(LIBBASENAME)
debug : $(LIBDIR)/debug/$(LIBBASENAME)
unittest : $(LIBDIR)/unittest/$(LIBBASENAME)

doc :
	@echo No documentation available for $(LIBBASENAME).

######################################################

clean :
	rm -f $(ALLLIBS) $(C_OBJS) $(AS_OBJS)

