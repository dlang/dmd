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

MODULES_ROOT= \
	object_.d

MODULES_BASE= \
	rt\aaA.d \
	rt\aApply.d \
	rt\aApplyR.d \
	rt\adi.d \
	rt\arrayassign.d \
	rt\arraybyte.d \
	rt\arraycast.d \
	rt\arraycat.d \
	rt\arraydouble.d \
	rt\arrayfloat.d \
	rt\arrayint.d \
	rt\arrayreal.d \
	rt\arrayshort.d \
	rt\cast_.d \
	rt\cover.d \
	rt\dmain2.d \
	rt\invariant.d \
	rt\invariant_.d \
	rt\lifetime.d \
	rt\llmath.d \
	rt\memory.d \
	rt\memset.d \
	rt\obj.d \
	rt\qsort.d \
	rt\switch_.d \
	rt\trace.d
# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for Linux

MODULES_UTIL= \
	rt\util\console.d \
	rt\util\ctype.d \
	rt\util\hash.d \
	rt\util\string.d \
	rt\util\utf.d

MODULES_TI= \
	rt\typeinfo\ti_AC.d \
	rt\typeinfo\ti_Acdouble.d \
	rt\typeinfo\ti_Acfloat.d \
	rt\typeinfo\ti_Acreal.d \
	rt\typeinfo\ti_Adouble.d \
	rt\typeinfo\ti_Afloat.d \
	rt\typeinfo\ti_Ag.d \
	rt\typeinfo\ti_Aint.d \
	rt\typeinfo\ti_Along.d \
	rt\typeinfo\ti_Areal.d \
	rt\typeinfo\ti_Ashort.d \
	rt\typeinfo\ti_byte.d \
	rt\typeinfo\ti_C.d \
	rt\typeinfo\ti_cdouble.d \
	rt\typeinfo\ti_cfloat.d \
	rt\typeinfo\ti_char.d \
	rt\typeinfo\ti_creal.d \
	rt\typeinfo\ti_dchar.d \
	rt\typeinfo\ti_delegate.d \
	rt\typeinfo\ti_double.d \
	rt\typeinfo\ti_float.d \
	rt\typeinfo\ti_idouble.d \
	rt\typeinfo\ti_ifloat.d \
	rt\typeinfo\ti_int.d \
	rt\typeinfo\ti_ireal.d \
	rt\typeinfo\ti_long.d \
	rt\typeinfo\ti_ptr.d \
	rt\typeinfo\ti_real.d \
	rt\typeinfo\ti_short.d \
	rt\typeinfo\ti_ubyte.d \
	rt\typeinfo\ti_uint.d \
	rt\typeinfo\ti_ulong.d \
	rt\typeinfo\ti_ushort.d \
	rt\typeinfo\ti_void.d \
	rt\typeinfo\ti_wchar.d

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
ALL_MODULES=$(MODULES_ROOT) $(MODULES_BASE) $(MODULES_UTIL) $(MODULES_TI)
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
