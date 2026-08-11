# This makefile is designed to be run by gnu make.
# - Windows: you may download a prebuilt zipped .exe from https://github.com/dlang/dmd/releases/download/nightly/gnumake-4.4-win64.zip.
#   You also need a Git for Windows installation, for bash and common GNU tools like cp,mkdir,mv,rm,touch,which.
# - FreeBSD: the default make program on FreeBSD is not gnu make; to install gnu make:
#     pkg install gmake
#   and then run as gmake rather than make.
#
# Examples:
# - Build druntime:
#     make -j$(nproc)
# - Build and run druntime tests:
#     make -j$(nproc) unittest
# - Build and run druntime tests in debug mode only:
#     make -j$(nproc) unittest-debug
# - Build druntime library using dmd bootstrap compiler by overriding DMD on command line such as:
#     make DMD=/Users/yourname/dmd2/osx/bin/dmd


QUIET:=

DUB=dub
TOOLS_DIR=../../tools

include ../compiler/src/osmodel.mak

ifeq (windows,$(OS))
    DOTEXE:=.exe
    DOTDLL:=.dll
    DOTLIB:=.lib
    DOTOBJ:=.obj
else
    DOTEXE:=
    DOTDLL:=$(if $(findstring $(OS),osx),.dylib,.so)
    DOTLIB:=.a
    DOTOBJ:=.o
endif

ifeq (osx,$(OS))
    export MACOSX_DEPLOYMENT_TARGET=10.9
endif

# Default to a release build, override with BUILD=debug
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

DMD=../generated/$(OS)/$(BUILD)/$(MODEL)/dmd$(DOTEXE)
INSTALL_DIR=../../install

# directory where the html files for the documentation are placed
DOC_OUTPUT_DIR=doc
IMPDIR=import

OPTIONAL_COVERAGE:=$(if $(TEST_COVERAGE),-cov=ctfe,)

# default to PIC, use PIC=1/0 to en-/disable PIC.
# Note that shared libraries and C files are always compiled with PIC.
ifeq (windows,$(OS))
    override PIC:=
else
    ifeq ($(PIC),)
        PIC:=1
    endif
    ifeq ($(PIC),1)
        override PIC:=-fPIC
    else
        override PIC:=
    endif
endif

# build with shared library support
# (defaults to true on supported platforms, can be overridden w/ make SHARED=0)
SHARED=$(if $(findstring $(OS),linux freebsd dragonflybsd hurd),1,)

LINKDL=$(if $(findstring $(OS),linux),-L-ldl,)

MAKEFILE = $(firstword $(MAKEFILE_LIST))

DDOCFLAGS=-conf= -c -w -o- -Iimport -version=CoreDdoc

# Set CFLAGS
CFLAGS=$(if $(findstring $(OS),windows),,$(MODEL_FLAG) -fPIC -DHAVE_UNISTD_H)
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

SHAREDFLAGS:=$(if $(findstring $(OS),windows),-visibility=public -mscrtlib=msvcrt,-fPIC)
SOLIBS:=$(if $(findstring $(OS),windows),msvcrt.lib legacy_stdio_definitions.lib,-L-lpthread -L-lm)

UTFLAGS:=-version=CoreUnittest -unittest -checkaction=context

# Set PHOBOS_DFLAGS (for linking against Phobos)
PHOBOS_PATH=../../phobos
ROOT_DIR := $(shell pwd)
PHOBOS_DFLAGS=-conf= $(MODEL_FLAG) -I$(ROOT_DIR)/import -I$(PHOBOS_PATH) -L-L$(PHOBOS_PATH)/generated/$(OS)/$(BUILD)/$(MODEL) $(PIC)
ifeq (1,$(SHARED))
PHOBOS_DFLAGS+=-defaultlib=libphobos2$(DOTDLL) -L-rpath=$(PHOBOS_PATH)/generated/$(OS)/$(BUILD)/$(MODEL)
endif

ROOT_OF_THEM_ALL = ../generated
ROOT = $(ROOT_OF_THEM_ALL)/$(OS)/$(BUILD)/$(MODEL)
OBJDIR=obj/$(OS)/$(BUILD)/$(MODEL)
DRUNTIME=$(ROOT)/$(if $(findstring $(OS),windows),,lib)druntime$(DOTLIB)
DRUNTIMESO_BASE=$(ROOT)/$(if $(findstring $(OS),windows),druntime_shared,libdruntime)
DRUNTIMESO=$(DRUNTIMESO_BASE)$(DOTDLL)
DRUNTIMESOOBJ=$(DRUNTIMESO)$(DOTOBJ)
DRUNTIMESOLIB=$(DRUNTIMESO)$(DOTLIB)

STDDOC=

include mak/COPY
COPY:=$(subst \,/,$(COPY))

include mak/DOCS
DOCS:=$(subst \,/,$(DOCS))

include mak/SRCS
SRCS:=$(subst \,/,$(SRCS))

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)

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

$(DOC_OUTPUT_DIR)/%.html : import/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_%.html : import/core/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_experimental_%.html : import/core/experimental/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_gc_%.html : import/core/gc/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_%.html : import/core/internal/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_array_%.html : import/core/internal/array/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_backtrace_%.html : import/core/internal/backtrace/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_container_%.html : import/core/internal/container/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_elf_%.html : import/core/internal/elf/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_gc_%.html : import/core/internal/gc/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_gc_impl_%.html : import/core/internal/gc/impl/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_gc_impl_conservative_%.html : import/core/internal/gc/impl/conservative/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_gc_impl_manual_%.html : import/core/internal/gc/impl/manual/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_gc_impl_proto_%.html : import/core/internal/gc/impl/proto/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_util_%.html : import/core/internal/util/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_internal_vararg_%.html : import/core/internal/vararg/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_stdc_%.html : import/core/stdc/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_stdcpp_%.html : import/core/stdcpp/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sync.html : import/core/sync/package.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sync_%.html : import/core/sync/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

# FIXME enable CRuntime_Bionic
$(DOC_OUTPUT_DIR)/core_sys_bionic_%.html : import/core/sys/bionic/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=linux -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_darwin_%.html : import/core/sys/darwin/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=osx -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_darwin_mach_%.html : import/core/sys/darwin/mach/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=osx -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_darwin_netinet_%.html : import/core/sys/darwin/netinet/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=osx -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_darwin_sys_%.html : import/core/sys/darwin/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=osx -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_dragonflybsd_%.html : import/core/sys/dragonflybsd/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=dragonflybsd -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_dragonflybsd_netinet_%.html : import/core/sys/dragonflybsd/netinet/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=dragonflybsd -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_dragonflybsd_sys_%.html : import/core/sys/dragonflybsd/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=dragonflybsd -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_elf_%.html : import/core/sys/elf/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_freebsd_%.html : import/core/sys/freebsd/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=freebsd -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_freebsd_netinet_%.html : import/core/sys/freebsd/netinet/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=freebsd -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_freebsd_sys_%.html : import/core/sys/freebsd/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=freebsd -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_linux_%.html : import/core/sys/linux/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=linux -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_linux_netinet_%.html : import/core/sys/linux/netinet/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=linux -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_linux_sys_%.html : import/core/sys/linux/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=linux -Df$@ project.ddoc $(DOCFMT) $<

# Note: no `-os=netbsd` option
$(DOC_OUTPUT_DIR)/core_sys_netbsd_%.html : import/core/sys/netbsd/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_netbsd_sys_%.html : import/core/sys/netbsd/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_openbsd_%.html : import/core/sys/openbsd/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=openbsd -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_openbsd_sys_%.html : import/core/sys/openbsd/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=openbsd -Df$@ project.ddoc $(DOCFMT) $<

# Use -os=linux to define Posix version
$(DOC_OUTPUT_DIR)/core_sys_posix_%.html : import/core/sys/posix/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=linux -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_posix_arpa_%.html : import/core/sys/posix/arpa/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=linux -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_posix_net_%.html : import/core/sys/posix/net/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=linux -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_posix_netinet_%.html : import/core/sys/posix/netinet/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=linux -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_posix_stdc_%.html : import/core/sys/posix/stdc/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=linux -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_posix_sys_%.html : import/core/sys/posix/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=linux -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_solaris_%.html : import/core/sys/solaris/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=solaris -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_solaris_sys_%.html : import/core/sys/solaris/sys/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=solaris -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_windows_%.html : import/core/sys/windows/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=windows -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_sys_windows_stdc_%.html : import/core/sys/windows/stdc/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -os=windows -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_thread.html : import/core/thread/package.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_thread_%.html : import/core/thread/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_thread_fiber.html : import/core/thread/fiber/package.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_thread_fiber_%.html : import/core/thread/fiber/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/core_builtins.html : import/core/builtins.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/etc_linux_%.html : import/etc/linux/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/etc_valgrind_%.html : import/etc/valgrind/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/gc_%.html : import/gc/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/gc_impl_%.html : import/gc/impl/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/gc_impl_conservative_%.html : import/gc/impl/conservative/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/gc_impl_manual_%.html : import/gc/impl/manual/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/gc_impl_proto_%.html : import/gc/impl/proto/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Df$@ project.ddoc $(DOCFMT) $<

# -Isrc added here because rt.* modules isn't purposed to import,
# i.e., not copied to import/ dir, but we want to generate documentation for them too
$(DOC_OUTPUT_DIR)/rt_%.html : src/rt/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Isrc -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/rt_typeinfo_%.html : src/rt/typeinfo/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Isrc -Df$@ project.ddoc $(DOCFMT) $<

$(DOC_OUTPUT_DIR)/rt_util_%.html : src/rt/util/%.d $(DMD)
	$(DMD) $(DDOCFLAGS) -Isrc -Df$@ project.ddoc $(DOCFMT) $<

######################## Header file copy ##############################

import: copy

copy: $(COPY)

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

../generated/$(OS)/$(BUILD)/$(MODEL)/dmd$(DOTEXE):
	$(MAKE) -C .. dmd BUILD=$(BUILD) OS=$(OS) MODEL=$(MODEL) DMD=""

# alias using the absolute path (the Phobos Makefile specifies an absolute path)
$(abspath ../generated/$(OS)/$(BUILD)/$(MODEL)/dmd$(DOTEXE)): ../generated/$(OS)/$(BUILD)/$(MODEL)/dmd$(DOTEXE)

################### C/ASM Targets ############################

OBJS:=$(ROOT)/errno_c$(DOTOBJ)
ifneq (windows,$(OS))
    OBJS+=$(ROOT)/threadasm$(DOTOBJ) $(ROOT)/valgrind$(DOTOBJ)
endif

$(ROOT)/%$(DOTOBJ) : src/rt/%.c $(DMD)
	@mkdir -p $(dir $@)
	$(DMD) -c $(DFLAGS) -I. $< -of$@

$(ROOT)/errno_c$(DOTOBJ) : src/core/stdc/errno.c $(DMD)
	@mkdir -p $(dir $@)
	$(DMD) -c $(DFLAGS) -I. -P=-I. $< -of$@

$(ROOT)/threadasm$(DOTOBJ) : src/core/thread/fiber/switch_context_asm.S
	@mkdir -p $(dir $@)
	$(CC) -c $(CFLAGS) $< -o$@

$(ROOT)/valgrind$(DOTOBJ) : src/etc/valgrind/valgrind.c src/etc/valgrind/valgrind.h src/etc/valgrind/memcheck.h
	@mkdir -p `dirname $@`
	$(CC) -c $(CFLAGS) $< -o$@

######################## Create a shared library ##############################

$(DRUNTIMESO) $(DRUNTIMESOLIB) dll: DFLAGS+=-version=Shared $(SHAREDFLAGS)
dll: $(DRUNTIMESOLIB)
dll_so: $(DRUNTIMESO)

$(DRUNTIMESO): $(OBJS) $(SRCS) $(DMD)
	$(DMD) -shared -debuglib= -defaultlib= -of$(DRUNTIMESO) $(DFLAGS) $(SRCS) $(OBJS) $(LINKDL) $(SOLIBS)

$(DRUNTIMESOLIB): $(OBJS) $(SRCS) $(DMD)
	$(DMD) -c $(if $(findstring $(OS),windows),,-fPIC) -of$(DRUNTIMESOOBJ) $(DFLAGS) $(SRCS)
	$(DMD) -conf= -lib -of$(DRUNTIMESOLIB) $(DRUNTIMESOOBJ) $(OBJS)

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) $(DMD)
	$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

lib: $(DRUNTIME)

################### WASM cross-target #########################
# Cross-compile the druntime archive for wasm32-wasip1, independent of the
# host build (OS/MODEL/BUILD).

WASM_DMD    ?= $(DMD)
WASM_ROOT   := $(ROOT_OF_THEM_ALL)/wasm/release/wasm32
WASM_LIB    := $(WASM_ROOT)/libdruntime-wasm.a
WASM_RT_DIR := src/rt/wasm
WASM_MODULES := start
WASM_OBJS   := $(addprefix $(WASM_ROOT)/rt_,$(addsuffix .o,$(WASM_MODULES)))
WASM_FLAGS  := -c -mwasm32 -os=wasm -betterC -conf= -Isrc -Iimport -w -de

# Built from the shared $(SRCS): OS-specific modules self-gate to empty on
# wasm through their existing `version` guards.  Filtered out here are the
# modules for other targets' complex types and exception handling.
WASM_DRT_EXCLUDE := \
	src/core/stdc/complex.d \
	src/rt/dwarfeh.d \
	src/rt/deh_win64_posix.d
WASM_DRT_SRCS := $(filter-out $(WASM_DRT_EXCLUDE),$(SRCS)) \
	src/rt/sections_wasm.d \
	src/rt/wasm/extra.d \
	src/rt/wasm/eh.d
WASM_DRT_FLAGS := -c -mwasm32 -os=wasm -conf= -Isrc -Iimport -w -de
# Map a source path to a unique object name: several sources share a basename,
# e.g. impl/{proto,manual,conservative}/gc.d and thread/package.d
wasm_obj = $(WASM_ROOT)/drt_$(subst /,_,$(basename $(patsubst src/%,%,$(1)))).o
WASM_DRT_OBJS := $(foreach s,$(WASM_DRT_SRCS),$(call wasm_obj,$(s)))

# wasi-libc's `_start` for betterC programs, added by dmd.link in betterC mode.
# An archive rather than an object, so a program defining its own `_start`
# leaves the member unpulled instead of colliding with it.
WASM_BETTERC_CRT := $(WASM_ROOT)/libcrt1_betterc.a
WASM_BETTERC_OBJ := $(WASM_ROOT)/crt1-command.o

# wasi-libc, fetched as a pinned and checksummed prebuilt libc.a from a
# wasi-sdk sysroot release (github.com/WebAssembly/wasi-sdk).  Keep
# WASI_SDK_VERSION in sync with the actions/cache key in
# .github/workflows/main.yml.  Set WASI_LIBC_LOCAL to a path to use a
# locally built libc.a instead.
WASM_LIBC            := $(WASM_ROOT)/libc.a
WASI_SDK_VERSION     ?= 33
WASI_SYSROOT_SHA256  ?= 063bc1b56582b9923e08ac9b89e58789618d851763f01530b3ff20b9e5df0ca3
# GitHub percent-encodes the '+' in the asset name as %2B in the download URL.
WASI_SYSROOT_URL     ?= https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-$(WASI_SDK_VERSION)/wasi-sysroot-$(WASI_SDK_VERSION).0%2Bm.tar.gz
WASI_SYSROOT_TARBALL := $(ROOT_OF_THEM_ALL)/wasm/wasi-sysroot-$(WASI_SDK_VERSION).tar.gz
WASI_LIBC_LOCAL      ?=
SHA256SUM            ?= sha256sum

$(WASM_ROOT)/rt_%.o : $(WASM_RT_DIR)/%.d $(DMD)
	@mkdir -p $(dir $@)
	$(WASM_DMD) $(WASM_FLAGS) -of$@ $<

$(WASM_BETTERC_CRT) : $(WASM_BETTERC_OBJ)
	rm -f $@
	$(WASM_DMD) -lib -mwasm32 -os=wasm -conf= -of$@ $<

# One pattern-free rule per real druntime source (sources live in different
# directories, so a static pattern rule can't map them).
define WASM_DRT_RULE
$(call wasm_obj,$(1)) : $(1) $(DMD)
	@mkdir -p $$(dir $$@)
	$(WASM_DMD) $(WASM_DRT_FLAGS) -of$$@ $(1)
endef
$(foreach s,$(WASM_DRT_SRCS),$(eval $(call WASM_DRT_RULE,$(s))))

# Coarse dependencies: these modules cross-import each other and the core.stdc
# bindings, so rebuild all of them when any druntime source changes.
$(WASM_DRT_OBJS) $(WASM_OBJS): $(WASM_DRT_SRCS) $(wildcard src/core/stdc/*.d) $(wildcard src/core/internal/*.d) $(wildcard src/rt/wasm/*.d)

$(WASM_LIB): $(WASM_OBJS) $(WASM_DRT_OBJS)
	rm -f $@
	$(WASM_DMD) -lib -mwasm32 -os=wasm -conf= -of$@ $(WASM_OBJS) $(WASM_DRT_OBJS)

$(WASM_LIBC) $(WASM_BETTERC_OBJ): $(WASM_ROOT)/% :
	@mkdir -p $(WASM_ROOT)
ifneq ($(WASI_LIBC_LOCAL),)
	cp $(dir $(WASI_LIBC_LOCAL))$* $@
else
	@mkdir -p $(dir $(WASI_SYSROOT_TARBALL))
	test -f $(WASI_SYSROOT_TARBALL) || curl -fSL -o $(WASI_SYSROOT_TARBALL) '$(WASI_SYSROOT_URL)'
	echo '$(WASI_SYSROOT_SHA256)  $(WASI_SYSROOT_TARBALL)' | $(SHA256SUM) -c -
	tar -xzOf $(WASI_SYSROOT_TARBALL) --wildcards --no-anchored '*/wasm32-wasip1/$*' > $@
	test -s $@ || { echo "wasm32-wasip1/$* not found in $(WASI_SYSROOT_TARBALL)"; rm -f $@; exit 1; }
endif

.PHONY: wasm
wasm: copy $(WASM_LIB) $(WASM_BETTERC_CRT) $(WASM_LIBC)

UT_SRCS:=$(SRCS)
UT_MODULES:=$(patsubst src/%.d,$(ROOT)/unittest/%,$(UT_SRCS))
HAS_ADDITIONAL_TESTS:=$(shell test -d test && echo 1)
ifeq ($(HAS_ADDITIONAL_TESTS),1)
    ADDITIONAL_TESTS:=test/init_fini test/exceptions test/coverage test/profile test/cycles test/allocations test/typeinfo \
        test/aa test/cpuid test/gc test/hash test/lifetime test/shared \
        test/thread test/unittest test/imports test/betterc test/stdcpp test/config test/traits test/importc_compare
    ifeq (windows,$(OS))
        ADDITIONAL_TESTS+=test/uuid test/link
    else
        ADDITIONAL_TESTS+=test/valgrind
    endif
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

$(ROOT)/unittest/test_runner$(DOTEXE): $(OBJS) $(SRCS) src/test_runner.d $(DMD)
	$(DMD) $(UDFLAGS) $(UTFLAGS) -of$@ src/test_runner.d $(SRCS) $(OBJS) -defaultlib= $(if $(findstring $(OS),windows),user32.lib,-L-lpthread -L-lm)

else

UT_DRUNTIME:=$(ROOT)/unittest/libdruntime-ut$(DOTDLL)
UT_DRUNTIMELIB:=$(ROOT)/unittest/libdruntime-ut$(if $(findstring $(OS),windows),$(DOTLIB),$(DOTDLL))

$(UT_DRUNTIME): UDFLAGS+=-version=Shared $(SHAREDFLAGS)
$(UT_DRUNTIME): $(OBJS) $(SRCS) $(DMD)
	$(DMD) $(UDFLAGS) -shared $(UTFLAGS) -of$@ $(SRCS) $(OBJS) $(LINKDL) -defaultlib= $(if $(findstring $(OS),windows),user32.lib -L/IMPLIB:$(UT_DRUNTIMELIB),) $(SOLIBS)

$(ROOT)/unittest/test_runner$(DOTEXE): $(UT_DRUNTIME) src/test_runner.d $(DMD)
	$(DMD) $(UDFLAGS) -of$@ src/test_runner.d -L$(UT_DRUNTIMELIB) -defaultlib= $(if $(findstring $(OS),windows),-dllimport=defaultLibsOnly user32.lib,-L-lpthread -L-lm)

endif

TESTS_EXTRACTOR=$(ROOT)/tests_extractor$(DOTEXE)
BETTERCTESTS_DIR=$(ROOT)/betterctests

# macro that returns the module name given the src path
moduleName=$(subst /,.,$(1))

$(ROOT)/unittest/% : $(ROOT)/unittest/test_runner$(DOTEXE)
	@mkdir -p $(dir $@)
# make the file very old so it builds and runs again if it fails
	@touch -t 197001230123 $@
# run unittest in its own directory
	$(QUIET)$(TIMELIMIT)$< $(call moduleName,$*)
# succeeded, render the file new again
	@touch $@

ifeq (,$(SHARED))
$(addsuffix /.run,$(ADDITIONAL_TESTS)): $(DRUNTIME)
else
$(addsuffix /.run,$(filter-out test/shared,$(ADDITIONAL_TESTS))): $(DRUNTIME)
test/shared/.run: $(DRUNTIMESO)
endif

ifeq (linux,$(OS))
    LDD = ldd
    IS_MUSL := $(shell $(LDD) --version 2>&1 | grep -q musl && echo 1)
endif

test/%/.run: test/%/Makefile $(DMD)
	$(QUIET)$(MAKE) -C test/$* MODEL=$(MODEL) OS=$(OS) DMD=$(abspath $(DMD)) BUILD=$(BUILD) \
		DRUNTIME=$(abspath $(DRUNTIME)) DRUNTIMESO=$(abspath $(DRUNTIMESO)) LINKDL=$(LINKDL) \
		QUIET=$(QUIET) TIMELIMIT='$(TIMELIMIT)' PIC=$(PIC) SHARED=$(SHARED) IS_MUSL=$(IS_MUSL)

test/%/.clean: test/%/Makefile
	$(QUIET)$(MAKE) -C test/$* MODEL=$(MODEL) OS=$(OS) BUILD=$(BUILD) clean
ifeq (0,$(BUILD_WAS_SPECIFIED))
	$(QUIET)$(MAKE) -C test/$* MODEL=$(MODEL) OS=$(OS) BUILD=debug clean
endif

#################### benchmark suite ##########################

$(ROOT)/benchmark$(DOTEXE): benchmark/runbench.d target $(DMD)
	$(DMD) $(PHOBOS_DFLAGS) -de $< -of$@

benchmark: $(ROOT)/benchmark$(DOTEXE)
	DMD=$(DMD) $<

benchmark-compile-only: $(ROOT)/benchmark$(DOTEXE) $(DMD)
	DMD=$(DMD) $< --repeat=0 --dflags="$(PHOBOS_DFLAGS) -de"

#################### test for undesired white spaces ##########################
MANIFEST = $(shell git ls-tree --name-only -r HEAD)

CWS_MAKEFILES = $(filter mak/% %.mak %/Makefile,$(MANIFEST))
NOT_MAKEFILES = $(filter-out $(CWS_MAKEFILES) test/%.exp,$(MANIFEST))
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
	mkdir -p '$(INSTALL_DIR)'/src/druntime/import
	cp -r import/* '$(INSTALL_DIR)'/src/druntime/import/
endif

clean: $(addsuffix /.clean,$(ADDITIONAL_TESTS))
	rm -rf $(ROOT_OF_THEM_ALL) $(IMPDIR) $(DOC_OUTPUT_DIR) druntime.zip

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
	mv $(TOOLS_DIR)/tests_extractor$(DOTEXE) $@

test_extractor: $(TESTS_EXTRACTOR)

################################################################################
# Check and run @betterC tests
# ----------------------------
#
# Extract @betterC tests of a module and run them in -betterC
#
#   make betterc -j20             # all tests
#   make src/core/memory.betterc  # individual module
################################################################################

betterc: | $(TESTS_EXTRACTOR) $(BETTERCTESTS_DIR)/.directory
	$(MAKE) $$(find src -type f -name '*.d' | sed 's/[.]d/.betterc/')

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
# make src/core/time.publictests
################################################################################
%.publictests: %.d $(TESTS_EXTRACTOR) $(DRUNTIME) | $(PUBLICTESTS_DIR)/.directory
	@$(TESTS_EXTRACTOR) --inputdir  $< --outputdir $(PUBLICTESTS_DIR)
	@$(DMD) -main $(UDFLAGS) -unittest -defaultlib= -debuglib= -od$(PUBLICTESTS_DIR) $(DRUNTIME) -run $(PUBLICTESTS_DIR)/$(subst /,_,$<)

################################################################################

.PHONY : buildkite-test
buildkite-test: unittest benchmark-compile-only

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)
