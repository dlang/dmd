# This makefile is designed to be run by gnu make.
# The default make program on FreeBSD 8.1 is not gnu make; to install gnu make:
#    pkg_add -r gmake
# and then run as gmake rather than make.

QUIET:=@

OS:=
uname_S:=$(shell uname -s)
ifeq (Darwin,$(uname_S))
	OS:=osx
endif
ifeq (Linux,$(uname_S))
	OS:=linux
endif
ifeq (FreeBSD,$(uname_S))
	OS:=freebsd
endif
ifeq (OpenBSD,$(uname_S))
	OS:=openbsd
endif
ifeq (Solaris,$(uname_S))
	OS:=solaris
endif
ifeq (SunOS,$(uname_S))
	OS:=solaris
endif
ifeq (,$(OS))
	$(error Unrecognized or unsupported OS for uname: $(uname_S))
endif

DMD?=dmd

DOCDIR=doc
IMPDIR=import

MODEL=32
# default to SHARED on some platforms
ifeq (linux,$(OS))
	ifeq (64,$(MODEL))
		SHARED:=1
	endif
endif
override PIC:=$(if $(or $(PIC), $(SHARED)),-fPIC,)

ifeq (osx,$(OS))
	DOTDLL:=.dylib
	DOTLIB:=.a
else
	DOTDLL:=.so
	DOTLIB:=.a
endif

DFLAGS=-m$(MODEL) -O -release -inline -w -Isrc -Iimport -property $(PIC)
UDFLAGS=-m$(MODEL) -O -release -w -Isrc -Iimport -property $(PIC)
DDOCFLAGS=-m$(MODEL) -c -w -o- -Isrc -Iimport

CFLAGS=-m$(MODEL) -O $(PIC)

ifeq (osx,$(OS))
    ASMFLAGS =
else
    ASMFLAGS = -Wa,--noexecstack
endif

OBJDIR=obj/$(MODEL)
DRUNTIME_BASE=druntime-$(OS)$(MODEL)
DRUNTIME=lib/lib$(DRUNTIME_BASE).a
DRUNTIMESO=lib/lib$(DRUNTIME_BASE).so

DOCFMT=-version=CoreDdoc

include mak/COPY
COPY:=$(subst \,/,$(COPY))

include mak/DOCS
DOCS:=$(subst \,/,$(DOCS))

include mak/IMPORTS
IMPORTS:=$(subst \,/,$(IMPORTS))

include mak/MANIFEST
MANIFEST:=$(subst \,/,$(MANIFEST))

include mak/SRCS
SRCS:=$(subst \,/,$(SRCS))

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32	 and
#       minit.asm is not used by dmd for Linux

OBJS= $(OBJDIR)/errno_c.o $(OBJDIR)/threadasm.o $(OBJDIR)/complex.o

######################## All of'em ##############################

target : import copy $(DRUNTIME) doc

######################## Doc .html file generation ##############################

doc: $(DOCS)

$(DOCDIR)/object.html : src/object_.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $<

$(DOCDIR)/core_%.html : src/core/%.di
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $<

$(DOCDIR)/core_%.html : src/core/%.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $<

$(DOCDIR)/core_sync_%.html : src/core/sync/%.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $<

######################## Header .di file generation ##############################

import: $(IMPORTS)

$(IMPDIR)/core/sync/%.di : src/core/sync/%.d
	@mkdir -p `dirname $@`
	$(DMD) -m$(MODEL) -c -o- -Isrc -Iimport -Hf$@ $<

######################## Header .di file copy ##############################

copy: $(COPY)

$(IMPDIR)/%.di : src/%.di
	@mkdir -p `dirname $@`
	cp $< $@

$(IMPDIR)/%.d : src/%.d
	@mkdir -p `dirname $@`
	cp $< $@

################### C/ASM Targets ############################

$(OBJDIR)/%.o : src/rt/%.c
	@mkdir -p `dirname $@`
	$(CC) -c $(CFLAGS) $< -o$@

$(OBJDIR)/errno_c.o : src/core/stdc/errno.c
	@mkdir -p `dirname $@`
	$(CC) -c $(CFLAGS) $< -o$@

$(OBJDIR)/threadasm.o : src/core/threadasm.S
	@mkdir -p $(OBJDIR)
	$(CC) $(ASMFLAGS) -c $(CFLAGS) $< -o$@

######################## Create a shared library ##############################

dll: override PIC:=-fPIC
dll: $(DRUNTIMESO)

$(DRUNTIMESO): $(OBJS) $(SRCS)
	$(DMD) -shared -of$(DRUNTIMESO) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS)
	$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

UT_MODULES:=$(patsubst src/%.d,$(OBJDIR)/%,$(SRCS))

unittest : $(UT_MODULES)
	@echo done

ifeq ($(OS),freebsd)
DISABLED_TESTS =
else
DISABLED_TESTS =
endif

$(addprefix $(OBJDIR)/,$(DISABLED_TESTS)) :
	@echo $@ - disabled

ifeq (,$(SHARED))

$(OBJDIR)/test_runner: $(OBJS) $(SRCS) src/test_runner.d
	$(DMD) $(UDFLAGS) -version=druntime_unittest -unittest -of$@ src/test_runner.d $(SRCS) $(OBJS) -debuglib= -defaultlib=

else

UT_DRUNTIME:=$(OBJDIR)/lib$(DRUNTIME_BASE)-ut$(DOTDLL)

$(UT_DRUNTIME): $(OBJS) $(SRCS)
	$(DMD) $(UDFLAGS) -shared -version=druntime_unittest -unittest -of$@ $(SRCS) $(OBJS) -debuglib= -defaultlib=

$(OBJDIR)/test_runner: $(UT_DRUNTIME) src/test_runner.d
	$(DMD) $(UDFLAGS) -of$@ src/test_runner.d -L-L$(OBJDIR) -L-rpath=$(OBJDIR) -debuglib=$(DRUNTIME_BASE)-ut -defaultlib=$(DRUNTIME_BASE)-ut

endif

# macro that returns the module name given the src path
moduleName=$(subst rt.invariant,invariant,$(subst object_,object,$(subst /,.,$(1))))

$(OBJDIR)/% : $(OBJDIR)/test_runner
	@mkdir -p $(dir $@)
# make the file very old so it builds and runs again if it fails
	@touch -t 197001230123 $@
# run unittest in its own directory
	$(QUIET)$(RUN) $(OBJDIR)/test_runner $(call moduleName,$*)
# succeeded, render the file new again
	@touch $@

detab:
	detab $(MANIFEST)
	tolf $(MANIFEST)

zip: druntime.zip

druntime.zip: $(MANIFEST) $(DOCS) $(IMPORTS)
	rm -rf $@
	zip $@ $^

install: druntime.zip
	unzip -o druntime.zip -d /dmd2/src/druntime

clean:
	rm -rf obj lib $(IMPDIR) $(DOCDIR) druntime.zip
