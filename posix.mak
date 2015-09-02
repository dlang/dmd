# This makefile is designed to be run by gnu make.
# The default make program on FreeBSD 8.1 is not gnu make; to install gnu make:
#    pkg_add -r gmake
# and then run as gmake rather than make.

QUIET:=@

include osmodel.mak

DMD=../dmd/src/dmd
INSTALL_DIR=../install

DOCDIR=doc
IMPDIR=import

override PIC:=$(if $(PIC),-fPIC,)

ifeq (osx,$(OS))
	DOTDLL:=.dylib
	DOTLIB:=.a
else
	DOTDLL:=.so
	DOTLIB:=.a
endif

DFLAGS=$(MODEL_FLAG) -conf= -O -release -dip25 -inline -w -Isrc -Iimport $(PIC)
UDFLAGS=$(MODEL_FLAG) -conf= -O -release -dip25 -w -Isrc -Iimport $(PIC)
DDOCFLAGS=-conf= -c -w -o- -Isrc -Iimport -version=CoreDdoc

CFLAGS=$(MODEL_FLAG) -O $(PIC)
ifeq (solaris,$(OS))
    CFLAGS+=-D_REENTRANT  # for thread-safe errno
endif

OBJDIR=obj/$(MODEL)
DRUNTIME_BASE=druntime-$(OS)$(MODEL)
DRUNTIME=lib/lib$(DRUNTIME_BASE).a
DRUNTIMESO=lib/lib$(DRUNTIME_BASE).so
DRUNTIMESOOBJ=lib/lib$(DRUNTIME_BASE)so.o
DRUNTIMESOLIB=lib/lib$(DRUNTIME_BASE)so.a

DOCFMT=

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

OBJS= $(OBJDIR)/errno_c.o $(OBJDIR)/bss_section.o $(OBJDIR)/threadasm.o

# build with shared library support
SHARED=$(if $(findstring $(OS),linux freebsd),1,)

LINKDL=$(if $(findstring $(OS),linux),-L-ldl,)

######################## All of'em ##############################

ifneq (,$(SHARED))
target : import copy dll $(DRUNTIME)
else
target : import copy $(DRUNTIME)
endif

######################## Doc .html file generation ##############################

doc: $(DOCS)

$(DOCDIR)/object.html : src/object.d
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOCDIR)/core_%.html : src/core/%.d
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOCDIR)/core_stdc_%.html : src/core/stdc/%.d
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOCDIR)/core_sync_%.html : src/core/sync/%.d
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

changelog.html: changelog.dd
	$(DMD) -Df$@ $<

######################## Header .di file generation ##############################

import: $(IMPORTS)

$(IMPDIR)/core/sync/%.di : src/core/sync/%.d
	@mkdir -p `dirname $@`
	$(DMD) -conf= -c -o- -Isrc -Iimport -Hf$@ $<

######################## Header .di file copy ##############################

copy: $(COPY)

$(IMPDIR)/object.d : src/object.d
	@mkdir -p `dirname $@`
	@rm -f $(IMPDIR)/object.di
	cp $< $@

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
	$(CC) -c $(CFLAGS) $< -o$@

######################## Create a shared library ##############################

$(DRUNTIMESO) $(DRUNTIMESOLIB) dll: override PIC:=-fPIC
$(DRUNTIMESO) $(DRUNTIMESOLIB) dll: DFLAGS+=-version=Shared
dll: $(DRUNTIMESOLIB)

$(DRUNTIMESO): $(OBJS) $(SRCS)
	$(DMD) -shared -debuglib= -defaultlib= -of$(DRUNTIMESO) $(DFLAGS) $(SRCS) $(OBJS) $(LINKDL)

$(DRUNTIMESOLIB): $(OBJS) $(SRCS)
	$(DMD) -c -fPIC -of$(DRUNTIMESOOBJ) $(DFLAGS) $(SRCS)
	$(DMD) -conf= -lib -of$(DRUNTIMESOLIB) $(DRUNTIMESOOBJ) $(OBJS)

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS)
	$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

UT_MODULES:=$(patsubst src/%.d,$(OBJDIR)/%,$(SRCS))
HAS_ADDITIONAL_TESTS:=$(shell test -d test && echo 1)
ifeq ($(HAS_ADDITIONAL_TESTS),1)
	ADDITIONAL_TESTS:=test/init_fini test/exceptions test/coverage test/profile
	ADDITIONAL_TESTS+=$(if $(SHARED),test/shared,)
endif

unittest : $(UT_MODULES) $(addsuffix /.run,$(ADDITIONAL_TESTS))
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
	$(DMD) $(UDFLAGS) -unittest -of$@ src/test_runner.d $(SRCS) $(OBJS) -debuglib= -defaultlib=

else

UT_DRUNTIME:=$(OBJDIR)/lib$(DRUNTIME_BASE)-ut$(DOTDLL)

$(UT_DRUNTIME): override PIC:=-fPIC
$(UT_DRUNTIME): UDFLAGS+=-version=Shared
$(UT_DRUNTIME): $(OBJS) $(SRCS)
	$(DMD) $(UDFLAGS) -shared -unittest -of$@ $(SRCS) $(OBJS) $(LINKDL) -debuglib= -defaultlib=

$(OBJDIR)/test_runner: $(UT_DRUNTIME) src/test_runner.d
	$(DMD) $(UDFLAGS) -of$@ src/test_runner.d -L$(UT_DRUNTIME) -debuglib= -defaultlib=

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

test/init_fini/.run test/exceptions/.run: $(DRUNTIME)
test/shared/.run: $(DRUNTIMESO)

test/%/.run: test/%/Makefile
	$(QUIET)$(MAKE) -C test/$* MODEL=$(MODEL) OS=$(OS) DMD=$(abspath $(DMD)) \
		DRUNTIME=$(abspath $(DRUNTIME)) DRUNTIMESO=$(abspath $(DRUNTIMESO)) QUIET=$(QUIET) LINKDL=$(LINKDL)

detab:
	detab $(MANIFEST)
	tolf $(MANIFEST)

zip: druntime.zip

druntime.zip: $(MANIFEST) $(IMPORTS)
	rm -rf $@
	zip $@ $^

install: target
	mkdir -p $(INSTALL_DIR)/src/druntime/import
	cp -r import/* $(INSTALL_DIR)/src/druntime/import/
	$(eval lib_dir=$(if $(filter $(OS),osx), lib, lib$(MODEL)))
	mkdir -p $(INSTALL_DIR)/$(OS)/$(lib_dir)
	cp -r lib/* $(INSTALL_DIR)/$(OS)/$(lib_dir)/
	cp LICENSE $(INSTALL_DIR)/druntime-LICENSE.txt

clean: $(addsuffix /.clean,$(ADDITIONAL_TESTS))
	rm -rf obj lib $(IMPDIR) $(DOCDIR) druntime.zip

test/%/.clean: test/%/Makefile
	$(MAKE) -C test/$* clean

.PHONY : auto-tester-build
auto-tester-build: target

.PHONY : auto-tester-test
auto-tester-test: unittest

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)
