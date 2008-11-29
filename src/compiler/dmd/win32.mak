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

SRC_BASE= \
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
#       minit.asm is not used by dmd for linux

SRC_UTIL= \
    util\console.d \
    util\cpuid.d \
    util\ctype.d \
    util\string.d \
    util\utf.d

SRC_TI= \
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

ALL_OBJS= \
	complex.obj \
	critical.obj \
	deh.obj \
	monitor.obj

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

$(LIB_TARGET) : $(ALL_OBJS) $(SRC_BASE) $(SRC_UTIL) $(SRC_TI)
	$(DC) -lib -of$@ $(DFLAGS) $(ALL_OBJS) $(SRC_BASE) $(SRC_UTIL) $(SRC_TI) minit.obj

dmd.doc : $(ALL_DOCS)
	@echo No documentation available.

minit.obj : minit.asm
	$(CC) -c minit.asm

######################################################

clean :
	$(RM) /s *.di
	$(RM) $(ALL_OBJS)
	$(RM) $(ALL_DOCS)
	$(RM) $(LIB_MASK)

install :
	$(MD) $(LIB_DEST)
	$(CP) $(LIB_MASK) $(LIB_DEST)\.
