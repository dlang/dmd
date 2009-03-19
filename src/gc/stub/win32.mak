# Makefile to build the garbage collector D library for Posix
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
LIBBASENAME=druntime_gc_stub.lib
#MODULES=gc
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

SRCS=gc.d
DOCS=
IMPORTS=
ALLLIBS=\
	$(LIBDIR)\debug\$(LIBBASENAME) \
	$(LIBDIR)\release\$(LIBBASENAME) \
	$(LIBDIR)\unittest\$(LIBBASENAME)

# Patterns

#$(LIBDIR)\%\$(LIBBASENAME) : $(SRCS)
#	$(DMD) $(DFLAGS_$*) -lib -of$@ $^

#$(DOCDIR)\%.html : %.d
#	$(DMD) -c -d -o- -Df$@ $<

#$(IMPDIR)\%.di : %.d
#	$(DMD) -c -d -o- -Hf$@ $<

# Patterns - debug

$(LIBDIR)\debug\$(LIBBASENAME) : $(SRCS)
	$(DMD) $(DFLAGS_debug) -lib -of$@ $**

# Patterns - release

$(LIBDIR)\release\$(LIBBASENAME) : $(SRCS)
	$(DMD) $(DFLAGS_release) -lib -of$@ $**

# Patterns - unittest

$(LIBDIR)\unittest\$(LIBBASENAME) : $(SRCS)
	$(DMD) $(DFLAGS_unittest) -lib -of$@ $**

# Rulez

all : $(BUILDS) doc

debug : $(LIBDIR)\debug\$(LIBBASENAME) $(IMPORTS)
release : $(LIBDIR)\release\$(LIBBASENAME) $(IMPORTS)
unittest : $(LIBDIR)\unittest\$(LIBBASENAME) $(IMPORTS)
#doc : $(DOCS)

clean :
	rm -f $(IMPORTS) $(DOCS) $(ALLLIBS)
