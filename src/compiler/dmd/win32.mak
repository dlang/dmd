# Makefile to build the compiler runtime D library for Win32
# Designed to work with DigitalMars make
# Targets:
#	make
#		Same as make all
#	make lib
#		Build the compiler runtime library
#   make doc
#       Generate documentation
#	make clean
#		Delete unneeded files created by build process

LIB_BASE=druntime-rt-dmd
LIB_BUILD=
LIB_TARGET=$(LIB_BASE)$(LIB_BUILD).lib
LIB_MASK=$(LIB_BASE)*.lib

CP=xcopy /y
RM=del /f
MD=mkdir

ADD_CFLAGS=
ADD_DFLAGS=

CFLAGS_RELEASE=-mn -6 -r $(ADD_CFLAGS)
CFLAGS_DEBUG=-g -mn -6 -r $(ADD_CFLAGS)
CFLAGS=$(CFLAGS_RELEASE)

DFLAGS_RELEASE=-release -O -inline -w -nofloat $(ADD_DFLAGS)
DFLAGS_DEBUG=-g -w -nofloat $(ADD_DFLAGS)
DFLAGS=$(DFLAGS_RELEASE)

TFLAGS_RELEASE=-O -inline -w  -nofloat $(ADD_DFLAGS)
TFLAGS_DEBUG=-g -w -nofloat $(ADD_DFLAGS)
TFLAGS=$(TFLAGS_RELEASE)

DOCFLAGS=-version=DDoc

CC=dmc
LC=lib
DC=dmd

LIB_DEST=..\..\..\lib

.DEFAULT: .asm .c .cpp .d .html .obj

.asm.obj:
	$(CC) -c $<

.c.obj:
	$(CC) -c $(CFLAGS) $< -o$@

.cpp.obj:
	$(CC) -c $(CFLAGS) $< -o$@

.d.obj:
	$(DC) -c $(DFLAGS) $< -of$@

.d.html:
	$(DC) -c -o- $(DOCFLAGS) -Df$*.html dmd.ddoc $<

targets : lib doc
all     : lib doc
lib     : dmd.lib
doc     : dmd.doc

######################################################

OBJ_BASE= \
    aaA.obj \
    aApply.obj \
    aApplyR.obj \
    adi.obj \
    arrayassign.obj \
    arraybyte.obj \
    arraycast.obj \
    arraycat.obj \
    arraydouble.obj \
    arrayfloat.obj \
    arrayint.obj \
    arrayreal.obj \
    arrayshort.obj \
    cast_.obj \
    complex.obj \
    cover.obj \
    critical.obj \
    deh.obj \
    dmain2.obj \
    invariant.obj \
    invariant_.obj \
    lifetime.obj \
    memory.obj \
    memset.obj \
    monitor.obj \
    obj.obj \
    object_.obj \
    qsort.obj \
    switch_.obj \
    trace.obj
# NOTE: trace.obj and cover.obj are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for linux

OBJ_UTIL= \
    util\console.obj \
    util\cpuid.obj \
    util\ctype.obj \
    util\string.obj \
    util\utf.obj

OBJ_TI= \
    typeinfo\ti_AC.obj \
    typeinfo\ti_Acdouble.obj \
    typeinfo\ti_Acfloat.obj \
    typeinfo\ti_Acreal.obj \
    typeinfo\ti_Adouble.obj \
    typeinfo\ti_Afloat.obj \
    typeinfo\ti_Ag.obj \
    typeinfo\ti_Aint.obj \
    typeinfo\ti_Along.obj \
    typeinfo\ti_Areal.obj \
    typeinfo\ti_Ashort.obj \
    typeinfo\ti_byte.obj \
    typeinfo\ti_C.obj \
    typeinfo\ti_cdouble.obj \
    typeinfo\ti_cfloat.obj \
    typeinfo\ti_char.obj \
    typeinfo\ti_creal.obj \
    typeinfo\ti_dchar.obj \
    typeinfo\ti_delegate.obj \
    typeinfo\ti_double.obj \
    typeinfo\ti_float.obj \
    typeinfo\ti_idouble.obj \
    typeinfo\ti_ifloat.obj \
    typeinfo\ti_int.obj \
    typeinfo\ti_ireal.obj \
    typeinfo\ti_long.obj \
    typeinfo\ti_ptr.obj \
    typeinfo\ti_real.obj \
    typeinfo\ti_short.obj \
    typeinfo\ti_ubyte.obj \
    typeinfo\ti_uint.obj \
    typeinfo\ti_ulong.obj \
    typeinfo\ti_ushort.obj \
    typeinfo\ti_void.obj \
    typeinfo\ti_wchar.obj

ALL_OBJS= \
    $(OBJ_BASE) \
    $(OBJ_UTIL) \
    $(OBJ_TI)

######################################################

ALL_DOCS=

######################################################

unittest :
	make -fwin32.mak DC="$(DC)" LIB_BUILD="" DFLAGS="$(DFLAGS_RELEASE) -unittest"

release :
	make -fwin32.mak DC="$(DC)" LIB_BUILD="" DFLAGS="$(DFLAGS_RELEASE)"

debug :
	make -fwin32.mak DC="$(DC)" LIB_BUILD="-d" DFLAGS="$(DFLAGS_DEBUG)"

######################################################

dmd.lib : $(LIB_TARGET)

$(LIB_TARGET) : $(ALL_OBJS)
	$(RM) $@
	$(LC) -c -n $@ $(ALL_OBJS) minit.obj

dmd.doc : $(ALL_DOCS)
	@echo No documentation available.

######################################################

clean :
	$(RM) /s *.di
	$(RM) $(ALL_OBJS)
	$(RM) $(ALL_DOCS)
	$(RM) $(LIB_MASK)

install :
	$(MD) $(LIB_DEST)
	$(CP) $(LIB_MASK) $(LIB_DEST)\.
