# Makefile to build the composite D runtime library for Win32
# Designed to work with DigitalMars make
# Targets:
#   make
#       Same as make all
#   make lib
#       Build the runtime library
#   make doc
#       Generate documentation
#   make clean
#       Delete unneeded files created by build process

LIB_BASE=druntime-dmd
LIB_BUILD=
LIB_TARGET=$(LIB_BASE)$(LIB_BUILD).lib
LIB_MASK=$(LIB_BASE)*.lib
DUP_TARGET=druntime$(LIB_BUILD).lib
DUP_MASK=druntime*.lib
MAKE_LIB=lib

DIR_CC=common
DIR_RT=compiler\dmd
DIR_GC=gc\basic
DIR_GC_STUB=gc\stub

LIB_CC=$(DIR_CC)\druntime-core$(LIB_BUILD).lib
LIB_RT=$(DIR_RT)\druntime-rt-dmd$(LIB_BUILD).lib
LIB_GC=$(DIR_GC)\druntime-gc-basic$(LIB_BUILD).lib

CP=xcopy /y
RM=del /f
MD=mkdir

CC=dmc
LC=lib
DC=dmd

LIB_DEST=..\lib

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

targets : lib doc
all     : lib doc

######################################################

OBJ_CORE= \
    common\core\bitmanip.obj \
    common\core\exception.obj \
    common\core\memory.obj \
    common\core\runtime.obj \
    common\core\thread.obj \
    common\core\vararg.obj

ALL_OBJS=

######################################################

ALL_DOCS=

######################################################

unittest : release $(OBJ_CORE)
	$(DC) $(DFLAGS_RELEASE) -L/co -unittest unittest.d $(OBJ_CORE) -defaultlib=$(DUP_TARGET) -debuglib=$(DUP_TARGET)
	unittest

release :
	make -fdmd-win32.mak lib DC=$(DC) MAKE_LIB="release"

debug :
	make -fdmd-win32.mak lib DC=$(DC) MAKE_LIB="debug" LIB_BUILD="-d"

######################################################

lib : $(ALL_OBJS)
	cd $(DIR_CC)
	make -fwin32.mak $(MAKE_LIB) DC=$(DC) ADD_DFLAGS="$(ADD_DFLAGS)" ADD_CFLAGS="$(ADD_CFLAGS)"
	cd ..
	cd $(DIR_RT)
	make -fwin32.mak $(MAKE_LIB) DC=$(DC) ADD_DFLAGS="$(ADD_DFLAGS)" ADD_CFLAGS="$(ADD_CFLAGS)"
	cd ..\..
	cd $(DIR_GC)
	make -fwin32.mak $(MAKE_LIB) DC=$(DC) ADD_DFLAGS="$(ADD_DFLAGS)" ADD_CFLAGS="$(ADD_CFLAGS)"
	cd ..\..
	cd $(DIR_GC_STUB)
	make -fwin32.mak $(MAKE_LIB) DC=$(DC) ADD_DFLAGS="$(ADD_DFLAGS)" ADD_CFLAGS="$(ADD_CFLAGS)"
	cd ..\..
	$(RM) $(LIB_TARGET)
	$(LC) -c -n $(LIB_TARGET) $(LIB_CC) $(LIB_RT) $(LIB_GC)
	$(RM) $(DUP_TARGET)
	copy $(LIB_TARGET) $(DUP_TARGET)


doc : $(ALL_DOCS)
	cd $(DIR_CC)
	make -fwin32.mak doc DC=$(DC)
	cd ..
	cd $(DIR_RT)
	make -fwin32.mak doc DC=$(DC)
	cd ..\..
	cd $(DIR_GC)
	make -fwin32.mak doc DC=$(DC)
	cd ..\..
	cd $(DIR_GC_STUB)
	make -fwin32.mak doc DC=$(DC)
	cd ..\..

######################################################

clean :
	$(RM) /s *.di
	$(RM) $(ALL_OBJS)
	$(RM) $(ALL_DOCS)
	cd $(DIR_CC)
	make -fwin32.mak clean
	cd ..
	cd $(DIR_RT)
	make -fwin32.mak clean
	cd ..\..
	cd $(DIR_GC)
	make -fwin32.mak clean
	cd ..\..
	cd $(DIR_GC_STUB)
	make -fwin32.mak clean
	cd ..\..
	$(RM) $(LIB_MASK)
	$(RM) $(DUP_MASK)
	$(RM) unittest.exe unittest.obj unittest.map

install :
	cd $(DIR_CC)
	make -fwin32.mak install
	cd ..
	cd $(DIR_RT)
	make -fwin32.mak install
	cd ..\..
	cd $(DIR_GC)
	make -fwin32.mak install
	cd ..\..
	cd $(DIR_GC_STUB)
	make -fwin32.mak install
	cd ..\..
	$(CP) $(LIB_MASK) $(LIB_DEST)\.
	$(CP) $(DUP_MASK) $(LIB_DEST)\.
