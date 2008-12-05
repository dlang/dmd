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

SRC_BASE= \
    aaA.d \
    aApply.d \
    aApplyR.d \
    adi.d \
    alloca.d \
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
    cmath2.d \
    complex.d \
    cover.d \
    critical.d \
    deh2.d \
    dmain2.d \
    invariant.d \
    invariant_.d \
    lifetime.d \
    llmath.d \
    memory.d \
    memset.d \
    monitor.d \
    obj.d \
    object_.d \
    qsort.d \
    switch_.d \
    trace.d
# NOTE: trace.o and cover.o are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for Linux
# NOTE: deh.o is only needed for Win32, Linux uses deh2.o

SRC_UTIL= \
    util/console.d \
    util/cpuid.d \
    util/ctype.d \
    util/string.d \
    util/utf.d

SRC_TI= \
    typeinfo/ti_AC.d \
    typeinfo/ti_Acdouble.d \
    typeinfo/ti_Acfloat.d \
    typeinfo/ti_Acreal.d \
    typeinfo/ti_Adouble.d \
    typeinfo/ti_Afloat.d \
    typeinfo/ti_Ag.d \
    typeinfo/ti_Aint.d \
    typeinfo/ti_Along.d \
    typeinfo/ti_Areal.d \
    typeinfo/ti_Ashort.d \
    typeinfo/ti_byte.d \
    typeinfo/ti_C.d \
    typeinfo/ti_cdouble.d \
    typeinfo/ti_cfloat.d \
    typeinfo/ti_char.d \
    typeinfo/ti_creal.d \
    typeinfo/ti_dchar.d \
    typeinfo/ti_delegate.d \
    typeinfo/ti_double.d \
    typeinfo/ti_float.d \
    typeinfo/ti_idouble.d \
    typeinfo/ti_ifloat.d \
    typeinfo/ti_int.d \
    typeinfo/ti_ireal.d \
    typeinfo/ti_long.d \
    typeinfo/ti_ptr.d \
    typeinfo/ti_real.d \
    typeinfo/ti_short.d \
    typeinfo/ti_ubyte.d \
    typeinfo/ti_uint.d \
    typeinfo/ti_ulong.d \
    typeinfo/ti_ushort.d \
    typeinfo/ti_void.d \
    typeinfo/ti_wchar.d

ALL_SRCS= \
    $(SRC_BASE) \
    $(SRC_UTIL) \
    $(SRC_TI)

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

$(LIB_TARGET) : $(ALL_SRCS) $(ALL_OBJS)
	$(DC) -lib -of$@ $(DFLAGS) $(ALL_SRCS) $(ALL_OBJS)

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
