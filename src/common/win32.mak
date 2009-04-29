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

LIBDIR=..\..\lib
DOCDIR=..\..\doc
IMPDIR=..\..\import
LIBBASENAME=druntime_core.lib
#MODULES=bitop exception memory runtime thread vararg \
#	$(addprefix sync/,barrier condition config exception mutex rwmutex semaphore)
BUILDS=debug release unittest

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

C_SRCS=core\stdc\errno.c

C_OBJS=errno.obj

D_SRCS=\
	core\bitop.d \
	core\exception.d \
	core\memory.d \
	core\runtime.d \
	core\thread.d \
	core\vararg.d \
	\
	core\sync\barrier.d \
	core\sync\condition.d \
	core\sync\config.d \
	core\sync\exception.d \
	core\sync\mutex.d \
	core\sync\rwmutex.d \
	core\sync\semaphore.d \
	\
	$(IMPDIR)\core\stdc\math.d \
	$(IMPDIR)\core\stdc\stdarg.d \
	$(IMPDIR)\core\stdc\stdio.d \
	$(IMPDIR)\core\stdc\wchar_.d \
	\
	$(IMPDIR)\core\sys\windows\windows.d

DOCS=\
	$(DOCDIR)\core\bitop.html \
	$(DOCDIR)\core\exception.html \
	$(DOCDIR)\core\memory.html \
	$(DOCDIR)\core\runtime.html \
	$(DOCDIR)\core\thread.html \
	$(DOCDIR)\core\vararg.html \
	\
	$(DOCDIR)\core\sync\barrier.html \
	$(DOCDIR)\core\sync\condition.html \
	$(DOCDIR)\core\sync\config.html \
	$(DOCDIR)\core\sync\exception.html \
	$(DOCDIR)\core\sync\mutex.html \
	$(DOCDIR)\core\sync\rwmutex.html \
	$(DOCDIR)\core\sync\semaphore.html

IMPORTS=\
	$(IMPDIR)\core\exception.di \
	$(IMPDIR)\core\memory.di \
	$(IMPDIR)\core\runtime.di \
	$(IMPDIR)\core\thread.di \
	$(IMPDIR)\core\vararg.di \
	\
	$(IMPDIR)\core\sync\barrier.di \
	$(IMPDIR)\core\sync\condition.di \
	$(IMPDIR)\core\sync\config.di \
	$(IMPDIR)\core\sync\exception.di \
	$(IMPDIR)\core\sync\mutex.di \
	$(IMPDIR)\core\sync\rwmutex.di \
	$(IMPDIR)\core\sync\semaphore.di
	# bitop.di is already published

ALLLIBS=\
	$(LIBDIR)\debug\$(LIBBASENAME) \
	$(LIBDIR)\release\$(LIBBASENAME) \
	$(LIBDIR)\unittest\$(LIBBASENAME)

# Patterns

#$(LIBDIR)\%\$(LIBBASENAME) : $(D_SRCS) $(C_SRCS)
#	$(CC) -c $(CFLAGS_$*) $(C_SRCS)
#	$(DMD) $(DFLAGS_$*) -lib -of$@ $(D_SRCS) $(C_OBJS)
#	del $(C_OBJS)

#$(DOCDIR)\%.html : %.d
#	$(DMD) -c -d -o- -Df$@ $<

#$(IMPDIR)\%.di : %.d
#	$(DMD) -c -d -o- -Hf$@ $<

# Patterns - debug

$(LIBDIR)\debug\$(LIBBASENAME) : $(D_SRCS) $(C_SRCS)
	$(CC) -c $(CFLAGS_debug) $(C_SRCS)
	$(DMD) $(DFLAGS_debug) -lib -of$@ $(D_SRCS) $(C_OBJS)
	del $(C_OBJS)

# Patterns - release

$(LIBDIR)\release\$(LIBBASENAME) : $(D_SRCS) $(C_SRCS)
	$(CC) -c $(CFLAGS_release) $(C_SRCS)
	$(DMD) $(DFLAGS_release) -lib -of$@ $(D_SRCS) $(C_OBJS)
	del $(C_OBJS)

# Patterns - unittest

$(LIBDIR)\unittest\$(LIBBASENAME) : $(D_SRCS) $(C_SRCS)
	$(CC) -c $(CFLAGS_unittest) $(C_SRCS)
	$(DMD) $(DFLAGS_unittest) -lib -of$@ $(D_SRCS) $(C_OBJS)
	del $(C_OBJS)

# Patterns - docs

$(DOCDIR)\core\bitop.html : core\bitop.d
	$(DMD) -c -d -o- -Df$@ $**

$(DOCDIR)\core\exception.html : core\exception.d
	$(DMD) -c -d -o- -Df$@ $**

$(DOCDIR)\core\memory.html : core\memory.d
	$(DMD) -c -d -o- -Df$@ $**

$(DOCDIR)\core\runtime.html : core\runtime.d
	$(DMD) -c -d -o- -Df$@ $**

$(DOCDIR)\core\thread.html : core\thread.d
	$(DMD) -c -d -o- -Df$@ $**

$(DOCDIR)\core\vararg.html : core\vararg.d
	$(DMD) -c -d -o- -Df$@ $**

$(DOCDIR)\core\sync\barrier.html : core\sync\barrier.d
	$(DMD) -c -d -o- -Df$@ $**

$(DOCDIR)\core\sync\condition.html : core\sync\condition.d
	$(DMD) -c -d -o- -Df$@ $**

$(DOCDIR)\core\sync\config.html : core\sync\config.d
	$(DMD) -c -d -o- -Df$@ $**

$(DOCDIR)\core\sync\exception.html : core\sync\exception.d
	$(DMD) -c -d -o- -Df$@ $**

$(DOCDIR)\core\sync\mutex.html : core\sync\mutex.d
	$(DMD) -c -d -o- -Df$@ $**

$(DOCDIR)\core\sync\rwmutex.html : core\sync\rwmutex.d
	$(DMD) -c -d -o- -Df$@ $**

$(DOCDIR)\core\sync\semaphore.html : core\sync\semaphore.d
	$(DMD) -c -d -o- -Df$@ $**

# Patterns - imports

$(IMPDIR)\core\exception.di : core\exception.d
	$(DMD) -c -d -o- -Hf$@ $**

$(IMPDIR)\core\memory.di : core\memory.d
	$(DMD) -c -d -o- -Hf$@ $**

$(IMPDIR)\core\runtime.di : core\runtime.d
	$(DMD) -c -d -o- -Hf$@ $**

$(IMPDIR)\core\thread.di : core\thread.d
	$(DMD) -c -d -o- -Hf$@ $**

$(IMPDIR)\core\vararg.di : core\vararg.d
	$(DMD) -c -d -o- -Hf$@ $**

$(IMPDIR)\core\sync\barrier.di : core\sync\barrier.d
	$(DMD) -c -d -o- -Hf$@ $**

$(IMPDIR)\core\sync\condition.di : core\sync\condition.d
	$(DMD) -c -d -o- -Hf$@ $**

$(IMPDIR)\core\sync\config.di : core\sync\config.d
	$(DMD) -c -d -o- -Hf$@ $**

$(IMPDIR)\core\sync\exception.di : core\sync\exception.d
	$(DMD) -c -d -o- -Hf$@ $**

$(IMPDIR)\core\sync\mutex.di : core\sync\mutex.d
	$(DMD) -c -d -o- -Hf$@ $**

$(IMPDIR)\core\sync\rwmutex.di : core\sync\rwmutex.d
	$(DMD) -c -d -o- -Hf$@ $**

$(IMPDIR)\core\sync\semaphore.di : core\sync\semaphore.d
	$(DMD) -c -d -o- -Hf$@ $**

# Rulez

all : $(BUILDS) doc

debug : $(LIBDIR)\debug\$(LIBBASENAME) $(IMPORTS)
release : $(LIBDIR)\release\$(LIBBASENAME) $(IMPORTS)
unittest : $(LIBDIR)\unittest\$(LIBBASENAME) $(IMPORTS)
doc : $(DOCS)

clean :
	del $(IMPORTS) $(DOCS) $(ALLLIBS)
