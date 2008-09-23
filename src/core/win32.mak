# Makefile to build the D runtime library core components for Win32
# Designed to work with DigitalMars make
# Targets:
#	make
#		Same as make all
#	make lib
#		Build the common library
#   make doc
#       Generate documentation
#	make clean
#		Delete unneeded files created by build process

LIB_TARGET=druntime-core.lib
LIB_MASK=druntime-core*.lib

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

INC_DEST=..\..\import
LIB_DEST=..\..\lib
DOC_DEST=..\..\doc

.DEFAULT: .asm .c .cpp .d .html .obj

.asm.obj:
	$(CC) -c $<

.c.obj:
	$(CC) -c $(CFLAGS) $< -o$@

.cpp.obj:
	$(CC) -c $(CFLAGS) $< -o$@

.d.obj:
	$(DC) -c $(DFLAGS) -Hf$*.di $< -of$@
#	$(DC) -c $(DFLAGS) $< -of$@

.d.html:
	$(DC) -c -o- $(DOCFLAGS) -Df$*.html $<

targets : lib doc
all     : lib doc
core    : lib
lib     : core.lib
doc     : core.doc

######################################################

OBJ_CORE= \
    bitmanip.obj \
    exception.obj \
    memory.obj \
    runtime.obj \
    thread.obj

OBJ_STDC= \
    stdc.obj

ALL_OBJS= \
    $(OBJ_CORE) \
    $(OBJ_STDC)

######################################################

DOC_CORE= \
    bitmanip.html \
    exception.html \
    memory.html \
    runtime.html \
    thread.html

ALL_DOCS=

######################################################

core.lib : $(LIB_TARGET)

$(LIB_TARGET) : $(ALL_OBJS)
	$(RM) $@
	$(LC) -c -n $@ $(ALL_OBJS)

core.doc : $(ALL_DOCS)
	@echo Documentation generated.

######################################################

### bitmanip

bitmanip.obj : bitmanip.d
	$(DC) -c $(DFLAGS) bitmanip.d -of$@

### thread

thread.obj : thread.d
	$(DC) -c $(DFLAGS) -d -Hf$*.di thread.d -of$@

######################################################

clean :
	$(RM) /s .\*.di
	$(RM) $(ALL_OBJS)
	$(RM) $(ALL_DOCS)
	$(RM) $(LIB_MASK)

install :
	$(MD) $(INC_DEST)
	$(CP) /s *.di $(INC_DEST)\.
	$(MD) $(DOC_DEST)
	$(CP) /s *.html $(DOC_DEST)\.
	$(MD) $(LIB_DEST)
	$(CP) $(LIB_MASK) $(LIB_DEST)\.
