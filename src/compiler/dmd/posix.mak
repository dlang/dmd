# Makefile to build the compiler runtime D library for Linux
# Designed to work with GNU make
# Targets:
#	make
#		Same as make all
#	make lib
#		Build the compiler runtime library
#   make doc
#       Generate documentation
#	make clean
#		Delete unneeded files created by build process

LIB_BASE=libdruntime-rt-dmd
LIB_BUILD=
LIB_TARGET=$(LIB_BASE)$(LIB_BUILD).a
LIB_MASK=$(LIB_BASE)*.a

CP=cp -f
RM=rm -f
MD=mkdir -p

ADD_CFLAGS=
ADD_DFLAGS=

CFLAGS_RELEASE=-O $(ADD_CFLAGS)
CFLAGS_DEBUG=-g $(ADD_CFLAGS)
CFLAGS=$(CFLAGS_RELEASE)

DFLAGS_RELEASE=-release -O -inline -w -nofloat $(ADD_DFLAGS)
DFLAGS_DEBUG=-g -w -nofloat $(ADD_DFLAGS)
DFLAGS=$(DFLAGS_RELEASE)

TFLAGS_RELEASE=-O -inline -w  -nofloat $(ADD_DFLAGS)
TFLAGS_DEBUG=-g -w -nofloat $(ADD_DFLAGS)
TFLAGS=$(TFLAGS_RELEASE)

DOCFLAGS=-version=DDoc

CC=gcc
LC=$(AR) -qsv
DC=dmd

LIB_DEST=../../../lib

.SUFFIXES: .s .S .c .cpp .d .html .o

.s.o:
	$(CC) -c $(CFLAGS) $< -o$@

.S.o:
	$(CC) -c $(CFLAGS) $< -o$@

.c.o:
	$(CC) -c $(CFLAGS) $< -o$@

.cpp.o:
	g++ -c $(CFLAGS) $< -o$@

.d.o:
	$(DC) -c $(DFLAGS) $< -of$@

.d.html:
	$(DC) -c -o- $(DOCFLAGS) -Df$*.html dmd.ddoc $<

targets : lib doc
all     : lib doc
lib     : dmd.lib
doc     : dmd.doc

######################################################

OBJ_BASE= \
    aaA.o \
    aApply.o \
    aApplyR.o \
    adi.o \
    alloca.o \
    arrayassign.o \
    arraybyte.o \
    arraycast.o \
    arraycat.o \
    arraydouble.o \
    arrayfloat.o \
    arrayint.o \
    arrayreal.o \
    arrayshort.o \
    cast_.o \
    cmath2.o \
    complex.o \
    cover.o \
    critical.o \
    deh2.o \
    dmain2.o \
    invariant.o \
    invariant_.o \
    lifetime.o \
    llmath.o \
    memory.o \
    memset.o \
    monitor.o \
    obj.o \
    object_.o \
    qsort.o \
    switch_.o \
    trace.o
# NOTE: trace.obj and cover.obj are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for linux
# NOTE: deh.o is only needed for Win32, linux uses deh2.o

OBJ_UTIL= \
    util/console.o \
    util/cpuid.o \
    util/ctype.o \
    util/string.o \
    util/utf.o

OBJ_TI= \
    typeinfo/ti_AC.o \
    typeinfo/ti_Acdouble.o \
    typeinfo/ti_Acfloat.o \
    typeinfo/ti_Acreal.o \
    typeinfo/ti_Adouble.o \
    typeinfo/ti_Afloat.o \
    typeinfo/ti_Ag.o \
    typeinfo/ti_Aint.o \
    typeinfo/ti_Along.o \
    typeinfo/ti_Areal.o \
    typeinfo/ti_Ashort.o \
    typeinfo/ti_byte.o \
    typeinfo/ti_C.o \
    typeinfo/ti_cdouble.o \
    typeinfo/ti_cfloat.o \
    typeinfo/ti_char.o \
    typeinfo/ti_creal.o \
    typeinfo/ti_dchar.o \
    typeinfo/ti_delegate.o \
    typeinfo/ti_double.o \
    typeinfo/ti_float.o \
    typeinfo/ti_idouble.o \
    typeinfo/ti_ifloat.o \
    typeinfo/ti_int.o \
    typeinfo/ti_ireal.o \
    typeinfo/ti_long.o \
    typeinfo/ti_ptr.o \
    typeinfo/ti_real.o \
    typeinfo/ti_short.o \
    typeinfo/ti_ubyte.o \
    typeinfo/ti_uint.o \
    typeinfo/ti_ulong.o \
    typeinfo/ti_ushort.o \
    typeinfo/ti_void.o \
    typeinfo/ti_wchar.o

ALL_OBJS= \
    $(OBJ_BASE) \
    $(OBJ_UTIL) \
    $(OBJ_TI)

######################################################

ALL_DOCS=

######################################################

unittest :
	make -fposix.mak DC="$(DC)" LIB_BUILD="" DFLAGS="$(DFLAGS_RELEASE) -unittest"

release :
	make -fposix.mak DC="$(DC)" LIB_BUILD="" DFLAGS="$(DFLAGS_RELEASE)"

debug :
	make -fposix.mak DC="$(DC)" LIB_BUILD="-d" DFLAGS="$(DFLAGS_DEBUG)"

######################################################

dmd.lib : $(LIB_TARGET)

$(LIB_TARGET) : $(ALL_OBJS)
	$(RM) $@
	$(LC) $@ $(ALL_OBJS)

dmd.doc : $(ALL_DOCS)
	echo No documentation available.

######################################################

clean :
	find . -name "*.di" | xargs $(RM)
	$(RM) $(ALL_OBJS)
	$(RM) $(ALL_DOCS)
	$(RM) $(LIB_MASK)

install :
	$(MD) $(LIB_DEST)
	$(CP) $(LIB_MASK) $(LIB_DEST)/.
