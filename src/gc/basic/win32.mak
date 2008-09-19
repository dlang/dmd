# Makefile to build the garbage collector D library for Win32
# Designed to work with DigitalMars make
# Targets:
#	make
#		Same as make all
#	make lib
#		Build the garbage collector library
#   make doc
#       Generate documentation
#	make clean
#		Delete unneeded files created by build process

LIB_TARGET=druntime-gc-basic.lib
LIB_MASK=druntime-gc-basic*.lib

CP=xcopy /y
RM=del /f
MD=mkdir

ADD_CFLAGS=
ADD_DFLAGS=

CFLAGS=-mn -6 -r $(ADD_CFLAGS)
#CFLAGS=-g -mn -6 -r $(ADD_CFLAGS)

DFLAGS=-release -O -inline -w -nofloat $(ADD_DFLAGS)
#DFLAGS=-g -w -nofloat $(ADD_DFLAGS)

TFLAGS=-O -inline -w  -nofloat $(ADD_DFLAGS)
#TFLAGS=-g -w -nofloat $(ADD_DFLAGS)

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
	$(DC) -c -o- $(DOCFLAGS) -Df$*.html $<
#	$(DC) -c -o- $(DOCFLAGS) -Df$*.html dmd.ddoc $<

targets : lib doc
all     : lib doc
lib     : basic.lib
doc     : basic.doc

######################################################

ALL_OBJS= \
    gc.obj \
    gcalloc.obj \
    gcbits.obj \
    gcstats.obj \
    gcx.obj

######################################################

ALL_DOCS=

######################################################

basic.lib : $(LIB_TARGET)

$(LIB_TARGET) : $(ALL_OBJS)
	$(RM) $@
	$(LC) -c -n $@ $(ALL_OBJS)

basic.doc : $(ALL_DOCS)
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
