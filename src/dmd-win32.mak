# Makefile to build the composite D runtime library for Win32
# Designed to work with DigitalMars make
# Targets:
#	make
#		Same as make all
#	make lib
#		Build the runtime library
#   make doc
#       Generate documentation
#	make clean
#		Delete unneeded files created by build process

LIB_TARGET=druntime-dmd.lib
LIB_MASK=druntime-dmd*.lib

DIR_CC=core
DIR_RT=compiler\dmd
DIR_GC=gc\basic

LIB_CC=$(DIR_CC)\druntime-core.lib
LIB_RT=$(DIR_RT)\druntime-rt-dmd.lib
LIB_GC=$(DIR_GC)\druntime-gc-basic.lib

CP=xcopy /y
RM=del /f
MD=mkdir

CC=dmc
LC=lib
DC=dmd

LIB_DEST=..\lib

ADD_CFLAGS=
ADD_DFLAGS=

targets : lib doc
all     : lib doc

######################################################

ALL_OBJS=

######################################################

ALL_DOCS=

######################################################

lib : $(ALL_OBJS)
	cd $(DIR_CC)
	make -fwin32.mak lib DC=$(DC) ADD_DFLAGS="$(ADD_DFLAGS)" ADD_CFLAGS="$(ADD_CFLAGS)"
	cd ..
	cd $(DIR_RT)
	make -fwin32.mak lib
	cd ..\..
	cd $(DIR_GC)
	make -fwin32.mak lib DC=$(DC) ADD_DFLAGS="$(ADD_DFLAGS)" ADD_CFLAGS="$(ADD_CFLAGS)"
	cd ..\..
	$(RM) $(LIB_TARGET)
	$(LC) -c -n $(LIB_TARGET) $(LIB_CC) $(LIB_RT) $(LIB_GC)

doc : $(ALL_DOCS)
	cd $(DIR_CC)
	make -fwin32.mak doc
	cd ..
	cd $(DIR_RT)
	make -fwin32.mak doc
	cd ..\..
	cd $(DIR_GC)
	make -fwin32.mak doc
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
	$(RM) $(LIB_MASK)

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
	$(CP) $(LIB_MASK) $(LIB_DEST)\.
