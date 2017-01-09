# This makefile is designed to be run by gnu make.
# The default make program on FreeBSD 8.1 is not gnu make; to install gnu make:
#    pkg_add -r gmake
# and then run as gmake rather than make.

QUIET:=

include osmodel.mak

# Default to a release built, override with BUILD=debug
ifeq (,$(BUILD))
BUILD_WAS_SPECIFIED=0
BUILD=release
else
BUILD_WAS_SPECIFIED=1
endif

ifneq ($(BUILD),release)
    ifneq ($(BUILD),debug)
        $(error Unrecognized BUILD=$(BUILD), must be 'debug' or 'release')
    endif
endif

DMD=../dmd/src/dmd
INSTALL_DIR=../install

DOCDIR=doc
IMPDIR=import

OPTIONAL_PIC:=$(if $(PIC),-fPIC,)
OPTIONAL_COVERAGE:=$(if $(TEST_COVERAGE),-cov,)

ifeq (osx,$(OS))
	DOTDLL:=.dylib
	DOTLIB:=.a
	export MACOSX_DEPLOYMENT_TARGET=10.7
else
	DOTDLL:=.so
	DOTLIB:=.a
endif

DDOCFLAGS=-conf= -c -w -o- -Isrc -Iimport -version=CoreDdoc

# Set CFLAGS
CFLAGS=$(MODEL_FLAG) -fPIC -DHAVE_UNISTD_H
ifeq ($(BUILD),debug)
	CFLAGS += -g
else
	CFLAGS += -O3
endif
ifeq (solaris,$(OS))
	CFLAGS+=-D_REENTRANT  # for thread-safe errno
endif

# Set DFLAGS
UDFLAGS:=-conf= -Isrc -Iimport -w -dip1000 $(MODEL_FLAG) $(OPTIONAL_PIC) $(OPTIONAL_COVERAGE)
ifeq ($(BUILD),debug)
	UDFLAGS += -g -debug
	DFLAGS:=$(UDFLAGS)
else
	UDFLAGS += -O -release
	DFLAGS:=$(UDFLAGS) -inline # unittests don't compile with -inline
endif

ROOT_OF_THEM_ALL = generated
ROOT = $(ROOT_OF_THEM_ALL)/$(OS)/$(BUILD)/$(MODEL)
OBJDIR=obj/$(OS)/$(BUILD)/$(MODEL)
DRUNTIME_BASE=druntime-$(OS)$(MODEL)
DRUNTIME=$(ROOT)/libdruntime.a
DRUNTIMESO=$(ROOT)/libdruntime.so
DRUNTIMESOOBJ=$(ROOT)/libdruntime.so.o
DRUNTIMESOLIB=$(ROOT)/libdruntime.so.a

DOCFMT=

include mak/COPY
COPY:=$(subst \,/,$(COPY))

include mak/DOCS
DOCS:=$(subst \,/,$(DOCS))

include mak/IMPORTS
IMPORTS:=$(subst \,/,$(IMPORTS))

include mak/SRCS
SRCS:=$(subst \,/,$(SRCS))

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32	 and
#       minit.asm is not used by dmd for Linux

OBJS= $(ROOT)/errno_c.o $(ROOT)/bss_section.o $(ROOT)/threadasm.o

ifeq ($(OS),osx)
ifeq ($(MODEL), 64)
	OBJS+=$(ROOT)/osx_tls.o
endif
endif

# build with shared library support
SHARED=$(if $(findstring $(OS),linux freebsd),1,)

LINKDL=$(if $(findstring $(OS),linux),-L-ldl,)

MAKEFILE = $(firstword $(MAKEFILE_LIST))

# use timelimit to avoid deadlocks if available
TIMELIMIT:=$(if $(shell which timelimit 2>/dev/null || true),timelimit -t 10 ,)

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

$(DOCDIR)/core_stdcpp_%.html : src/core/stdcpp/%.d
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOCDIR)/core_sync_%.html : src/core/sync/%.d
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

changelog.html: changelog.dd
	$(DMD) -Df$@ $<

######################## Header .di file generation ##############################

import: $(IMPORTS)

$(IMPDIR)/core/sync/%.di : src/core/sync/%.d
	@mkdir -p $(dir $@)
	$(DMD) -conf= -c -o- -Isrc -Iimport -Hf$@ $<

######################## Header .di file copy ##############################

copy: $(COPY)

$(IMPDIR)/object.d : src/object.d
	@mkdir -p $(dir $@)
	@rm -f $(IMPDIR)/object.di
	cp $< $@

$(IMPDIR)/%.di : src/%.di
	@mkdir -p $(dir $@)
	cp $< $@

$(IMPDIR)/%.d : src/%.d
	@mkdir -p $(dir $@)
	cp $< $@

################### C/ASM Targets ############################

$(ROOT)/%.o : src/rt/%.c
	@mkdir -p $(dir $@)
	$(CC) -c $(CFLAGS) $< -o$@

$(ROOT)/errno_c.o : src/core/stdc/errno.c
	@mkdir -p $(dir $@)
	$(CC) -c $(CFLAGS) $< -o$@

$(ROOT)/threadasm.o : src/core/threadasm.S
	@mkdir -p $(dir $@)
	$(CC) -c $(CFLAGS) $< -o$@

######################## Create a shared library ##############################

$(DRUNTIMESO) $(DRUNTIMESOLIB) dll: DFLAGS+=-version=Shared -fPIC
dll: $(DRUNTIMESOLIB)

$(DRUNTIMESO): $(OBJS) $(SRCS)
	$(DMD) -shared -debuglib= -defaultlib= -of$(DRUNTIMESO) $(DFLAGS) $(SRCS) $(OBJS) $(LINKDL)

$(DRUNTIMESOLIB): $(OBJS) $(SRCS)
	$(DMD) -c -fPIC -of$(DRUNTIMESOOBJ) $(DFLAGS) $(SRCS)
	$(DMD) -conf= -lib -of$(DRUNTIMESOLIB) $(DRUNTIMESOOBJ) $(OBJS)

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS)
	$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

UT_MODULES:=$(patsubst src/%.d,$(ROOT)/unittest/%,$(SRCS))
HAS_ADDITIONAL_TESTS:=$(shell test -d test && echo 1)
ifeq ($(HAS_ADDITIONAL_TESTS),1)
	ADDITIONAL_TESTS:=test/init_fini test/exceptions test/coverage test/profile test/cycles
	ADDITIONAL_TESTS+=$(if $(SHARED),test/shared,)
endif

.PHONY : unittest
ifeq (1,$(BUILD_WAS_SPECIFIED))
unittest : $(UT_MODULES) $(addsuffix /.run,$(ADDITIONAL_TESTS))
	@echo done
else
unittest : unittest-debug unittest-release
unittest-%:
	$(MAKE) -f $(MAKEFILE) unittest OS=$(OS) MODEL=$(MODEL) DMD=$(DMD) BUILD=$*
endif

ifeq ($(OS),linux)
  old_kernel:=$(shell [ "$$(uname -r | cut -d'-' -f1)" \< "2.6.39" ] && echo 1)
  ifeq ($(old_kernel),1)
    UDFLAGS+=-version=Linux_Pre_2639
  endif
endif

ifeq ($(OS),freebsd)
DISABLED_TESTS =
else
DISABLED_TESTS =
endif

$(addprefix $(ROOT)/unittest/,$(DISABLED_TESTS)) :
	@echo $@ - disabled

ifeq (,$(SHARED))

$(ROOT)/unittest/test_runner: $(OBJS) $(SRCS) src/test_runner.d
	$(DMD) $(UDFLAGS) -unittest -of$@ src/test_runner.d $(SRCS) $(OBJS) -debuglib= -defaultlib=

else

UT_DRUNTIME:=$(ROOT)/unittest/libdruntime-ut$(DOTDLL)

$(UT_DRUNTIME): UDFLAGS+=-version=Shared -fPIC
$(UT_DRUNTIME): $(OBJS) $(SRCS)
	$(DMD) $(UDFLAGS) -shared -unittest -of$@ $(SRCS) $(OBJS) $(LINKDL) -debuglib= -defaultlib=

$(ROOT)/unittest/test_runner: $(UT_DRUNTIME) src/test_runner.d
	$(DMD) $(UDFLAGS) -of$@ src/test_runner.d -L$(UT_DRUNTIME) -debuglib= -defaultlib=

endif

# macro that returns the module name given the src path
moduleName=$(subst rt.invariant,invariant,$(subst object_,object,$(subst /,.,$(1))))

$(ROOT)/unittest/% : $(ROOT)/unittest/test_runner
	@mkdir -p $(dir $@)
# make the file very old so it builds and runs again if it fails
	@touch -t 197001230123 $@
# run unittest in its own directory
	$(QUIET)$(TIMELIMIT)$< $(call moduleName,$*)
# succeeded, render the file new again
	@touch $@

$(addsuffix /.run,$(filter-out test/shared,$(ADDITIONAL_TESTS))): $(DRUNTIME)
test/shared/.run: $(DRUNTIMESO)

test/%/.run: test/%/Makefile
	$(QUIET)$(MAKE) -C test/$* MODEL=$(MODEL) OS=$(OS) DMD=$(abspath $(DMD)) BUILD=$(BUILD) \
		DRUNTIME=$(abspath $(DRUNTIME)) DRUNTIMESO=$(abspath $(DRUNTIMESO)) LINKDL=$(LINKDL) \
		QUIET=$(QUIET) TIMELIMIT='$(TIMELIMIT)'

#################### test for undesired white spaces ##########################
MANIFEST = $(shell git ls-tree --name-only -r HEAD)

CWS_MAKEFILES = $(filter mak/% %.mak %/Makefile,$(MANIFEST))
NOT_MAKEFILES = $(filter-out $(CWS_MAKEFILES) src/rt/minit.obj test/%.exp,$(MANIFEST))
GREP = grep

checkwhitespace:
# restrict to linux, other platforms don't have a version of grep that supports -P
ifeq (linux,$(OS))
	$(GREP) -n -U -P "([ \t]$$|\r)" $(CWS_MAKEFILES) ; test "$$?" -ne 0
	$(GREP) -n -U -P "( $$|\r|\t)" $(NOT_MAKEFILES) ; test "$$?" -ne 0
endif

detab:
	detab $(MANIFEST)
	tolf $(MANIFEST)


gitzip:
	git archive --format=zip HEAD > druntime.zip

zip: druntime.zip

druntime.zip: $(MANIFEST)
	rm -rf $@
	zip $@ $^

install: target
	mkdir -p $(INSTALL_DIR)/src/druntime/import
	cp -r import/* $(INSTALL_DIR)/src/druntime/import/
	cp LICENSE $(INSTALL_DIR)/druntime-LICENSE.txt

clean: $(addsuffix /.clean,$(ADDITIONAL_TESTS))
	rm -rf $(ROOT_OF_THEM_ALL) $(IMPDIR) $(DOCDIR) druntime.zip

test/%/.clean: test/%/Makefile
	$(MAKE) -C test/$* clean

# Submission to Druntime are required to conform to the DStyle
# The tests below automate some, but not all parts of the DStyle guidelines.
# See: http://dlang.org/dstyle.html
style: checkwhitespace

.PHONY : auto-tester-build
auto-tester-build: target checkwhitespace

.PHONY : auto-tester-test
auto-tester-test: unittest

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)
