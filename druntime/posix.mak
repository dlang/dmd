# This makefile is designed to be run by gnu make.
# The default make program on FreeBSD 8.1 is not gnu make; to install gnu make:
#    pkg_add -r gmake
# and then run as gmake rather than make.

QUIET:=

DMD_DIR=../compiler
DUB=dub
TOOLS_DIR=../../tools

include $(DMD_DIR)/src/osmodel.mak

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

DMD=$(DMD_DIR)/../generated/$(OS)/$(BUILD)/$(MODEL)/dmd
INSTALL_DIR=../../install

# directory where the html files for the documentation are placed
DOC_OUTPUT_DIR=doc
IMPDIR=import

OPTIONAL_COVERAGE:=$(if $(TEST_COVERAGE),-cov=ctfe,)

# default to PIC, use PIC=1/0 to en-/disable PIC.
# Note that shared libraries and C files are always compiled with PIC.
ifeq ($(PIC),)
    PIC:=1
endif
ifeq ($(PIC),1)
    override PIC:=-fPIC
else
    override PIC:=
endif

ifeq (osx,$(OS))
	DOTDLL:=.dylib
	DOTLIB:=.a
	export MACOSX_DEPLOYMENT_TARGET=10.9
else
	DOTDLL:=.so
	DOTLIB:=.a
endif

# build with shared library support
# (defaults to true on supported platforms, can be overridden w/ make SHARED=0)
SHARED=$(if $(findstring $(OS),linux freebsd dragonflybsd),1,)

LINKDL=$(if $(findstring $(OS),linux),-L-ldl,)

MAKEFILE = $(firstword $(MAKEFILE_LIST))

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
ifeq (osx,$(OS))
	ifeq (64,$(MODEL))
		CFLAGS+=--target=x86_64-darwin-apple  # ARM cpu is not supported by dmd
	endif
endif

# Set DFLAGS
UDFLAGS:=-conf= -Isrc -Iimport -w -de -preview=dip1000 -preview=fieldwise $(MODEL_FLAG) $(PIC) $(OPTIONAL_COVERAGE) -preview=dtorfields
ifeq ($(BUILD),debug)
	UDFLAGS += -g -debug
	DFLAGS:=$(UDFLAGS)
else
	UDFLAGS += -O -release
	DFLAGS:=$(UDFLAGS) -inline # unittests don't compile with -inline
endif

UTFLAGS:=-version=CoreUnittest -unittest -checkaction=context

# Set PHOBOS_DFLAGS (for linking against Phobos)
PHOBOS_PATH=../../phobos
SHARED=$(if $(findstring $(OS),linux freebsd),1,)
ROOT_DIR := $(shell pwd)
PHOBOS_DFLAGS=-conf= $(MODEL_FLAG) -I$(ROOT_DIR)/import -I$(PHOBOS_PATH) -L-L$(PHOBOS_PATH)/generated/$(OS)/$(BUILD)/$(MODEL) $(PIC)
ifeq (1,$(SHARED))
PHOBOS_DFLAGS+=-defaultlib=libphobos2.so -L-rpath=$(PHOBOS_PATH)/generated/$(OS)/$(BUILD)/$(MODEL)
endif

ROOT_OF_THEM_ALL = ../generated
ROOT = $(ROOT_OF_THEM_ALL)/$(OS)/$(BUILD)/$(MODEL)
OBJDIR=obj/$(OS)/$(BUILD)/$(MODEL)
DRUNTIME_BASE=druntime-$(OS)$(MODEL)
DRUNTIME=$(ROOT)/libdruntime.a
DRUNTIMESO=$(ROOT)/libdruntime.so
DRUNTIMESOOBJ=$(ROOT)/libdruntime.so.o
DRUNTIMESOLIB=$(ROOT)/libdruntime.so.a

STDDOC=

include mak/COPY
COPY:=$(subst \,/,$(COPY))

include mak/DOCS
DOCS:=$(subst \,/,$(DOCS))

include mak/SRCS
SRCS:=$(subst \,/,$(SRCS))

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32	 and
#       minit.asm is not used by dmd for Linux

OBJS= $(ROOT)/errno_c.o $(ROOT)/threadasm.o $(ROOT)/valgrind.o

# use timelimit to avoid deadlocks if available
TIMELIMIT:=$(if $(shell which timelimit 2>/dev/null || true),timelimit -t 10 ,)

######################## All of'em ##############################

ifneq (,$(SHARED))
target : copy dll $(DRUNTIME)
else
target : copy $(DRUNTIME)
endif

######################## Doc .html file generation ##############################

doc: $(DOCS)

$(DOC_OUTPUT_DIR)/%.html : src/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_%.html : src/core/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_experimental_%.html : src/core/experimental/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_gc_%.html : src/core/gc/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_%.html : src/core/internal/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_array_%.html : src/core/internal/array/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_backtrace_%.html : src/core/internal/backtrace/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_container_%.html : src/core/internal/container/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_elf_%.html : src/core/internal/elf/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_gc_%.html : src/core/internal/gc/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_gc_impl_%.html : src/core/internal/gc/impl/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_gc_impl_conservative_%.html : src/core/internal/gc/impl/conservative/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_gc_impl_manual_%.html : src/core/internal/gc/impl/manual/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_gc_impl_proto_%.html : src/core/internal/gc/impl/proto/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_util_%.html : src/core/internal/util/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_vararg_%.html : src/core/internal/vararg/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_stdc_%.html : src/core/stdc/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_stdcpp_%.html : src/core/stdcpp/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sync.html : src/core/sync/package.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sync_%.html : src/core/sync/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_bionic_%.html : src/core/sys/bionic/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_darwin_%.html : src/core/sys/darwin/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_darwin_mach_%.html : src/core/sys/darwin/mach/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_darwin_netinet_%.html : src/core/sys/darwin/netinet/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_darwin_sys_%.html : src/core/sys/darwin/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_dragonflybsd_%.html : src/core/sys/dragonflybsd/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_dragonflybsd_netinet_%.html : src/core/sys/dragonflybsd/netinet/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_dragonflybsd_sys_%.html : src/core/sys/dragonflybsd/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_elf_%.html : src/core/sys/elf/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_freebsd_%.html : src/core/sys/freebsd/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_freebsd_netinet_%.html : src/core/sys/freebsd/netinet/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_freebsd_sys_%.html : src/core/sys/freebsd/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_linux_%.html : src/core/sys/linux/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_linux_netinet_%.html : src/core/sys/linux/netinet/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_linux_sys_%.html : src/core/sys/linux/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_netbsd_%.html : src/core/sys/netbsd/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_netbsd_sys_%.html : src/core/sys/netbsd/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_openbsd_%.html : src/core/sys/openbsd/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_openbsd_sys_%.html : src/core/sys/openbsd/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_posix_%.html : src/core/sys/posix/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_posix_arpa_%.html : src/core/sys/posix/arpa/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_posix_net_%.html : src/core/sys/posix/net/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_posix_netinet_%.html : src/core/sys/posix/netinet/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_posix_stdc_%.html : src/core/sys/posix/stdc/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_posix_sys_%.html : src/core/sys/posix/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_solaris_%.html : src/core/sys/solaris/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_solaris_sys_%.html : src/core/sys/solaris/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_windows_%.html : src/core/sys/windows/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_windows_stdc_%.html : src/core/sys/windows/stdc/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_thread.html : src/core/thread/package.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_thread_%.html : src/core/thread/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_builtins.html : src/core/builtins.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/etc_linux_%.html : src/etc/linux/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/gc_%.html : src/gc/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/gc_impl_%.html : src/gc/impl/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/gc_impl_conservative_%.html : src/gc/impl/conservative/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/gc_impl_manual_%.html : src/gc/impl/manual/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/gc_impl_proto_%.html : src/gc/impl/proto/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/rt_%.html : src/rt/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/rt_typeinfo_%.html : src/rt/typeinfo/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/rt_util_%.html : src/rt/util/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

######################## Header file copy ##############################

import: copy

copy: $(COPY)

$(IMPDIR)/object.d : src/object.d
	@mkdir -p $(dir $@)
	@cp $< $@

$(IMPDIR)/%.di : src/%.di
	@mkdir -p $(dir $@)
	@cp $< $@

$(IMPDIR)/%.d : src/%.d
	@mkdir -p $(dir $@)
	@cp $< $@

$(IMPDIR)/%.h : src/%.h
	@mkdir -p $(dir $@)
	@cp $< $@

######################## Build DMD if non-existent ##############################

$(DMD):
	$(MAKE) -C $(DMD_DIR)/src -f posix.mak BUILD=$(BUILD) OS=$(OS) MODEL=$(MODEL)

################### C/ASM Targets ############################

$(ROOT)/%.o : src/rt/%.c $(DMD)
	@mkdir -p $(dir $@)
	$(DMD) -c $(DFLAGS) -I. $< -of$@

$(ROOT)/errno_c.o : src/core/stdc/errno.c $(DMD)
	@mkdir -p $(dir $@)
	$(DMD) -c $(DFLAGS) -I. $< -of$@

$(ROOT)/threadasm.o : src/core/threadasm.S
	@mkdir -p $(dir $@)
	$(CC) -c $(CFLAGS) $< -o$@

$(ROOT)/valgrind.o : src/etc/valgrind/valgrind.c src/etc/valgrind/valgrind.h src/etc/valgrind/memcheck.h
	@mkdir -p `dirname $@`
	$(CC) -c $(CFLAGS) $< -o$@

######################## Create a shared library ##############################

$(DRUNTIMESO) $(DRUNTIMESOLIB) dll: DFLAGS+=-version=Shared -fPIC
dll: $(DRUNTIMESOLIB)

$(DRUNTIMESO): $(OBJS) $(SRCS) $(DMD)
	$(DMD) -shared -debuglib= -defaultlib= -of$(DRUNTIMESO) $(DFLAGS) $(SRCS) $(OBJS) $(LINKDL) -L-lpthread -L-lm

$(DRUNTIMESOLIB): $(OBJS) $(SRCS) $(DMD)
	$(DMD) -c -fPIC -of$(DRUNTIMESOOBJ) $(DFLAGS) $(SRCS)
	$(DMD) -conf= -lib -of$(DRUNTIMESOLIB) $(DRUNTIMESOOBJ) $(OBJS)

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) $(DMD)
	$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

lib: $(DRUNTIME)

UT_MODULES:=$(patsubst src/%.d,$(ROOT)/unittest/%,$(SRCS))
HAS_ADDITIONAL_TESTS:=$(shell test -d test && echo 1)
ifeq ($(HAS_ADDITIONAL_TESTS),1)
	ADDITIONAL_TESTS:=test/init_fini test/exceptions test/coverage test/profile test/cycles test/allocations test/typeinfo \
	    test/aa test/cpuid test/gc test/hash test/lifetime \
	    test/thread test/unittest test/imports test/betterc test/stdcpp test/config \
	    test/traits test/valgrind
	ADDITIONAL_TESTS+=$(if $(SHARED),test/shared,)
endif

.PHONY : unittest
ifeq (1,$(BUILD_WAS_SPECIFIED))
unittest : $(UT_MODULES) $(addsuffix /.run,$(ADDITIONAL_TESTS))
else
unittest : unittest-debug unittest-release
unittest-%: target
	$(MAKE) -f $(MAKEFILE) unittest OS=$(OS) MODEL=$(MODEL) DMD=$(DMD) BUILD=$*
endif

ifeq ($(OS),linux)
  old_kernel:=$(shell [ "$$(uname -r | cut -d'-' -f1)" \< "2.6.39" ] && echo 1)
  ifeq ($(old_kernel),1)
    UDFLAGS+=-version=Linux_Pre_2639
  endif
endif

DISABLED_TESTS =

$(addprefix $(ROOT)/unittest/,$(DISABLED_TESTS)) :
	@echo $@ - disabled

ifeq (,$(SHARED))

$(ROOT)/unittest/test_runner: $(OBJS) $(SRCS) src/test_runner.d $(DMD)
	$(DMD) $(UDFLAGS) $(UTFLAGS) -of$@ src/test_runner.d $(SRCS) $(OBJS) -debuglib= -defaultlib= -L-lpthread -L-lm

else

UT_DRUNTIME:=$(ROOT)/unittest/libdruntime-ut$(DOTDLL)

$(UT_DRUNTIME): UDFLAGS+=-version=Shared -fPIC
$(UT_DRUNTIME): $(OBJS) $(SRCS) $(DMD)
	$(DMD) $(UDFLAGS) -shared $(UTFLAGS) -of$@ $(SRCS) $(OBJS) $(LINKDL) -debuglib= -defaultlib= -L-lpthread -L-lm

$(ROOT)/unittest/test_runner: $(UT_DRUNTIME) src/test_runner.d $(DMD)
	$(DMD) $(UDFLAGS) -of$@ src/test_runner.d -L$(UT_DRUNTIME) -debuglib= -defaultlib= -L-lpthread -L-lm

endif

TESTS_EXTRACTOR=$(ROOT)/tests_extractor
BETTERCTESTS_DIR=$(ROOT)/betterctests

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

test/%/.run: test/%/Makefile $(DMD)
	$(QUIET)$(MAKE) -C test/$* MODEL=$(MODEL) OS=$(OS) DMD=$(abspath $(DMD)) BUILD=$(BUILD) \
		DRUNTIME=$(abspath $(DRUNTIME)) DRUNTIMESO=$(abspath $(DRUNTIMESO)) LINKDL=$(LINKDL) \
		QUIET=$(QUIET) TIMELIMIT='$(TIMELIMIT)' PIC=$(PIC)

#################### benchmark suite ##########################

$(ROOT)/benchmark: benchmark/runbench.d target $(DMD)
	$(DMD) $(PHOBOS_DFLAGS) -de $< -of$@

benchmark: $(ROOT)/benchmark
	DMD=$(DMD) $<

benchmark-compile-only: $(ROOT)/benchmark $(DMD)
	DMD=$(DMD) $< --repeat=0 --dflags="$(PHOBOS_DFLAGS) -de"

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

ifneq (,$(findstring Darwin_64_32, $(PWD)))
install:
	echo "Darwin_64_32_disabled"
else
install: target
	mkdir -p $(INSTALL_DIR)/src/druntime/import
	cp -r import/* $(INSTALL_DIR)/src/druntime/import/
endif

clean: $(addsuffix /.clean,$(ADDITIONAL_TESTS))
	rm -rf $(ROOT_OF_THEM_ALL) $(IMPDIR) $(DOC_OUTPUT_DIR) druntime.zip

test/%/.clean: test/%/Makefile
	$(MAKE) -C test/$* clean

%/.directory :
	mkdir -p $* || exists $*
	touch $@

################################################################################
# Build the test extractor.
# - extracts and runs public unittest examples to checks for missing imports
# - extracts and runs @betterC unittests
################################################################################

$(TESTS_EXTRACTOR): $(TOOLS_DIR)/tests_extractor.d | $(LIB)
	$(DUB) build --force --single $<
	mv $(TOOLS_DIR)/tests_extractor $@

test_extractor: $(TESTS_EXTRACTOR)

################################################################################
# Check and run @betterC tests
# ----------------------------
#
# Extract @betterC tests of a module and run them in -betterC
#
#   make -f betterc -j20                       # all tests
#   make -f posix.mak src/core/memory.betterc  # individual module
################################################################################

betterc: | $(TESTS_EXTRACTOR) $(BETTERCTESTS_DIR)/.directory
	$(MAKE) -f posix.mak $$(find src -type f -name '*.d' | sed 's/[.]d/.betterc/')

%.betterc: %.d | $(TESTS_EXTRACTOR) $(BETTERCTESTS_DIR)/.directory
	@$(TESTS_EXTRACTOR) --betterC --attributes betterC \
		--inputdir  $< --outputdir $(BETTERCTESTS_DIR)
	@$(DMD) $(NODEFAULTLIB) -betterC $(UDFLAGS) $(UTFLAGS) -od$(BETTERCTESTS_DIR) -run $(BETTERCTESTS_DIR)/$(subst /,_,$<)

################################################################################

# Submission to Druntime are required to conform to the DStyle
# The tests below automate some, but not all parts of the DStyle guidelines.
# See: http://dlang.org/dstyle.html
style: checkwhitespace style_lint

style_lint:
	@echo "Check for trailing whitespace"
	$(GREP) -nr '[[:blank:]]$$' $(MANIFEST) ; test $$? -eq 1

	@echo "Enforce whitespace before opening parenthesis"
	$(GREP) -nrE "\<(for|foreach|foreach_reverse|if|while|switch|catch|version)\(" $$(find src -name '*.d') ; test $$? -eq 1

	@echo "Enforce no whitespace after opening parenthesis"
	$(GREP) -nrE "\<(version) \( " $$(find src -name '*.d') ; test $$? -eq 1

################################################################################
# Check for missing imports in public unittest examples.
################################################################################

PUBLICTESTS_DIR=$(ROOT)/publictests
publictests: $(addsuffix .publictests, $(basename $(SRCS)))

################################################################################
# Extract public tests of a module and test them in an separate file (i.e. without its module)
# This is done to check for potentially missing imports in the examples, e.g.
# make -f posix.mak src/core/time.publictests
################################################################################
%.publictests: %.d $(TESTS_EXTRACTOR) $(DRUNTIME) | $(PUBLICTESTS_DIR)/.directory
	@$(TESTS_EXTRACTOR) --inputdir  $< --outputdir $(PUBLICTESTS_DIR)
	@$(DMD) -main $(UDFLAGS) -unittest -defaultlib= -debuglib= -od$(PUBLICTESTS_DIR) $(DRUNTIME) -run $(PUBLICTESTS_DIR)/$(subst /,_,$<)

################################################################################

.PHONY : buildkite-test
buildkite-test: unittest benchmark-compile-only

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)
