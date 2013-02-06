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
override PIC:=$(if $(PIC),-fPIC,)

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

DOCFMT=-version=CoreDdoc

include mak/posix.mak

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32	 and
#       minit.asm is not used by dmd for Linux

OBJS:= $(OBJDIR)/errno_c.o $(OBJDIR)/threadasm.o $(OBJDIR)/complex.o


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

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS)
	$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

UT_MODULES:=$(patsubst src/%.d,$(OBJDIR)/%,$(SRCS))

unittest : $(UT_MODULES) $(DRUNTIME) $(OBJDIR)/emptymain.d
	@echo done

ifeq ($(OS),freebsd)
DISABLED_TESTS =
else
DISABLED_TESTS =
endif

$(addprefix $(OBJDIR)/,$(DISABLED_TESTS)) :
	@echo $@ - disabled

$(OBJDIR)/% : src/%.d $(DRUNTIME) $(OBJDIR)/emptymain.d
	@echo Testing $@
	$(QUIET)$(DMD) $(UDFLAGS) -version=druntime_unittest -unittest -of$@ $(OBJDIR)/emptymain.d $< -L-Llib -debuglib=$(DRUNTIME_BASE) -defaultlib=$(DRUNTIME_BASE)
# make the file very old so it builds and runs again if it fails
	@touch -t 197001230123 $@
# run unittest in its own directory
	$(QUIET)$(RUN) $@
# succeeded, render the file new again
	@touch $@

$(OBJDIR)/emptymain.d :
	@mkdir -p $(OBJDIR)
	@echo 'void main(){}' >$@

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
