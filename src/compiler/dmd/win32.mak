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

LIBDIR=..\..\..\lib
DOCDIR=..\..\..\doc
IMPDIR=..\..\..\import
LIBBASENAME=druntime_rt_dmd.lib
#MODULES=bitop exception memory runtime thread vararg \
#	$(addprefix sync/,barrier condition config exception mutex rwmutex semaphore)
BUILDS=debug release unittest

MODULES_BASE= \
	aaA.d \
	aApply.d \
	aApplyR.d \
	adi.d \
	arrayassign.d \
	arraybyte.d \
	arraycast.d \
	arraycat.d \
	arraydouble.d \
	arrayfloat.d \
	arrayint.d \
	arrayreal.d \
	arrayshort.d \
	cast_.d \
	cover.d \
	dmain2.d \
	invariant.d \
	invariant_.d \
	lifetime.d \
	memory.d \
	memset.d \
	obj.d \
	object_.d \
	qsort.d \
	switch_.d \
	trace.d
# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for Linux

MODULES_UTIL= \
	util\console.d \
	util\cpuid.d \
	util\ctype.d \
	util\string.d \
	util\utf.d

MODULES_TI= \
	typeinfo\ti_AC.d \
	typeinfo\ti_Acdouble.d \
	typeinfo\ti_Acfloat.d \
	typeinfo\ti_Acreal.d \
	typeinfo\ti_Adouble.d \
	typeinfo\ti_Afloat.d \
	typeinfo\ti_Ag.d \
	typeinfo\ti_Aint.d \
	typeinfo\ti_Along.d \
	typeinfo\ti_Areal.d \
	typeinfo\ti_Ashort.d \
	typeinfo\ti_byte.d \
	typeinfo\ti_C.d \
	typeinfo\ti_cdouble.d \
	typeinfo\ti_cfloat.d \
	typeinfo\ti_char.d \
	typeinfo\ti_creal.d \
	typeinfo\ti_dchar.d \
	typeinfo\ti_delegate.d \
	typeinfo\ti_double.d \
	typeinfo\ti_float.d \
	typeinfo\ti_idouble.d \
	typeinfo\ti_ifloat.d \
	typeinfo\ti_int.d \
	typeinfo\ti_ireal.d \
	typeinfo\ti_long.d \
	typeinfo\ti_ptr.d \
	typeinfo\ti_real.d \
	typeinfo\ti_short.d \
	typeinfo\ti_ubyte.d \
	typeinfo\ti_uint.d \
	typeinfo\ti_ulong.d \
	typeinfo\ti_ushort.d \
	typeinfo\ti_void.d \
	typeinfo\ti_wchar.d

C_SRCS=complex.c critical.c deh.c monitor.c

# Symbols

CC=dmc
DMD=dmd
DOCFLAGS=-version=DDoc
DFLAGS_release=-d -release -O -inline -w -nofloat
DFLAGS_debug=-d -g -w -nofloat
DFLAGS_unittest=$(DFLAGS_release) -unittest
CFLAGS_release=-mn -6 -r
CFLAGS_debug=-g -mn -6 -r
CFLAGS_unittest=$(CFLAGS_release)

# Derived symbols

C_OBJS=complex.obj critical.obj deh.obj monitor.obj
AS_OBJS=minit.obj
ALL_MODULES=$(MODULES_BASE) $(MODULES_UTIL) $(MODULES_TI)
D_SRCS=$(ALL_MODULES)
ALLLIBS=\
	$(LIBDIR)\debug\$(LIBBASENAME) \
	$(LIBDIR)\release\$(LIBBASENAME) \
	$(LIBDIR)\unittest\$(LIBBASENAME)

# Patterns

#$(LIBDIR)\%\$(LIBBASENAME) : $(D_SRCS) $(C_SRCS) $(AS_OBJS)
#	$(CC) -c $(CFLAGS_$*) $(C_SRCS)
#	$(DMD) $(DFLAGS_$*) -lib -of$@ $(D_SRCS) $(C_OBJS) $(AS_OBJS)
#	del $(C_OBJS)

#$(DOCDIR)\%.html : %.d
#	$(DMD) -c -d -o- -Df$@ $<

#$(IMPDIR)\%.di : %.d
#	$(DMD) -c -d -o- -Hf$@ $<

# Patterns - debug

$(LIBDIR)\debug\$(LIBBASENAME) : $(D_SRCS) $(C_SRCS) $(AS_OBJS)
	$(CC) -c $(CFLAGS_debug) $(C_SRCS)
	$(DMD) $(DFLAGS_debug) -lib -of$@ $(D_SRCS) $(C_OBJS) $(AS_OBJS)
	del $(C_OBJS)

# Patterns - release

$(LIBDIR)\release\$(LIBBASENAME) : $(D_SRCS) $(C_SRCS) $(AS_OBJS)
	$(CC) -c $(CFLAGS_release) $(C_SRCS)
	$(DMD) $(DFLAGS_release) -lib -of$@ $(D_SRCS) $(C_OBJS) $(AS_OBJS)
	del $(C_OBJS)

# Patterns - unittest

$(LIBDIR)\unittest\$(LIBBASENAME) : $(D_SRCS) $(C_SRCS) $(AS_OBJS)
	$(CC) -c $(CFLAGS_unittest) $(C_SRCS)
	$(DMD) $(DFLAGS_unittest) -lib -of$@ $(D_SRCS) $(C_OBJS) $(AS_OBJS)
	del $(C_OBJS)

# Patterns - asm

minit.obj : minit.asm
	$(CC) -c $**

# Rulez

all : $(BUILDS) doc

debug : $(LIBDIR)\debug\$(LIBBASENAME) $(IMPORTS)
release : $(LIBDIR)\release\$(LIBBASENAME) $(IMPORTS)
unittest : $(LIBDIR)\unittest\$(LIBBASENAME) $(IMPORTS)
#doc : $(DOCS)

clean :
	del $(IMPORTS) $(DOCS) $(ALLLIBS)
