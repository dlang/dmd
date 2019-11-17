################################################################################
# Important variables:
# --------------------
#
# HOST_CXX:             Host C++ compiler to use (g++,clang++)
# HOST_DMD:             Host D compiler to use for bootstrapping
# AUTO_BOOTSTRAP:       Enable auto-boostrapping by downloading a stable DMD binary
# INSTALL_DIR:          Installation folder to use
# MODEL:                Target architecture to build for (32,64) - defaults to the host architecture
#
################################################################################
# Build modes:
# ------------
# BUILD: release (default) | debug (enabled a build with debug instructions)
#
# Opt-in build features:
#
# ENABLE_RELEASE:       Optimized release built
# ENABLE_DEBUG:         Add debug instructions and symbols (set if ENABLE_RELEASE isn't set)
# ENABLE_WARNINGS:      Enable C++ build warnings
# ENABLE_PROFILING:     Build dmd with a profiling recorder (C++)
# ENABLE_PGO_USE:       Build dmd with existing profiling information (C++)
#   PGO_DIR:            Directory for profile-guided optimization (PGO) logs
# ENABLE_LTO:           Enable link-time optimizations
# ENABLE_UNITTEST:      Build dmd with unittests (sets ENABLE_COVERAGE=1)
# ENABLE_PROFILE:       Build dmd with a profiling recorder (D)
# ENABLE_COVERAGE       Build dmd with coverage counting
# ENABLE_SANITIZERS     Build dmd with sanitizer (e.g. ENABLE_SANITIZERS=address,undefined)
#
# Targets
# -------
#
# all					Build dmd
# unittest              Run all unittest blocks
# cxx-unittest          Check conformance of the C++ headers
# build-examples        Build DMD as library examples
# clean                 Remove all generated files
# man                   Generate the man pages
# checkwhitespace       Checks for trailing whitespace and tabs
# zip                   Packs all sources into a ZIP archive
# gitzip                Packs all sources into a ZIP archive
# install               Installs dmd into $(INSTALL_DIR)
################################################################################

# get OS and MODEL
include osmodel.mak

ifeq (,$(TARGET_CPU))
    $(info no cpu specified, assuming X86)
    TARGET_CPU=X86
endif

# Default to a release built, override with BUILD=debug
ifeq (,$(BUILD))
BUILD=release
endif

ifneq ($(BUILD),release)
    ifneq ($(BUILD),debug)
        $(error Unrecognized BUILD=$(BUILD), must be 'debug' or 'release')
    endif
    ENABLE_DEBUG := 1
endif

# default to PIC on x86_64, use PIC=1/0 to en-/disable PIC.
# Note that shared libraries and C files are always compiled with PIC.
ifeq ($(PIC),)
    ifeq ($(MODEL),64) # x86_64
        PIC:=1
    else
        PIC:=0
    endif
endif
ifeq ($(PIC),1)
    override PIC:=-fPIC
else
    override PIC:=
endif

INSTALL_DIR=../../install
SYSCONFDIR=/etc
TMP?=/tmp
PGO_DIR=$(abspath pgo)

D = dmd

C=$D/backend
ROOT=$D/root
EX=examples
RES=../res

GENERATED = ../generated
G = $(GENERATED)/$(OS)/$(BUILD)/$(MODEL)
$(shell mkdir -p $G)

ifeq (osx,$(OS))
    export MACOSX_DEPLOYMENT_TARGET=10.9
endif

HOST_CXX=c++
# compatibility with old behavior
ifneq ($(HOST_CC),)
  $(warning ===== WARNING: Please use HOST_CXX=$(HOST_CC) instead of HOST_CC=$(HOST_CC). =====)
  HOST_CXX=$(HOST_CC)
endif
CXX=$(HOST_CXX)
AR=ar
GIT=git

# determine whether CXX is gcc or clang based
CXX_VERSION:=$(shell $(CXX) --version)
ifneq (,$(findstring g++,$(CXX_VERSION))$(findstring gcc,$(CXX_VERSION))$(findstring Free Software,$(CXX_VERSION)))
	CXX_KIND=g++
endif
ifneq (,$(findstring clang,$(CXX_VERSION)))
	CXX_KIND=clang++
endif

HOST_DC?=
ifneq (,$(HOST_DC))
  $(warning ========== Use HOST_DMD instead of HOST_DC ========== )
  HOST_DMD=$(HOST_DC)
endif

# Host D compiler for bootstrapping
ifeq (,$(AUTO_BOOTSTRAP))
  # No bootstrap, a $(HOST_DC) installation must be available
  HOST_DMD?=dmd
  HOST_DMD_PATH=$(abspath $(shell which $(HOST_DMD)))
  ifeq (,$(HOST_DMD_PATH))
    $(error '$(HOST_DMD)' not found, get a D compiler or make AUTO_BOOTSTRAP=1)
  endif
  HOST_DMD_RUN:=$(HOST_DMD)
else
  # Auto-bootstrapping, will download dmd automatically
  # Keep var below in sync with other occurrences of that variable, e.g. in circleci.sh
  HOST_DMD_VER=2.088.0
  HOST_DMD_ROOT=$(GENERATED)/host_dmd-$(HOST_DMD_VER)
  # dmd.2.088.0.osx.zip or dmd.2.088.0.linux.tar.xz
  HOST_DMD_BASENAME=dmd.$(HOST_DMD_VER).$(OS)$(if $(filter $(OS),freebsd),-$(MODEL),)
  # http://downloads.dlang.org/releases/2.x/2.088.0/dmd.2.088.0.linux.tar.xz
  HOST_DMD_URL=http://downloads.dlang.org/releases/2.x/$(HOST_DMD_VER)/$(HOST_DMD_BASENAME)
  HOST_DMD=$(HOST_DMD_ROOT)/dmd2/$(OS)/$(if $(filter $(OS),osx),bin,bin$(MODEL))/dmd
  HOST_DMD_PATH=$(HOST_DMD)
  HOST_DMD_RUN=$(HOST_DMD) -conf=$(dir $(HOST_DMD))dmd.conf
endif

HOST_DMD_VERSION:=$(shell $(HOST_DMD_RUN) --version)
ifneq (,$(findstring dmd,$(HOST_DMD_VERSION))$(findstring DMD,$(HOST_DMD_VERSION)))
	HOST_DMD_KIND=dmd
	HOST_DMD_VERNUM=$(shell echo 'pragma(msg, cast(int)__VERSION__);' | $(HOST_DMD_RUN) -o- - 2>&1)
endif
ifneq (,$(findstring gdc,$(HOST_DMD_VERSION))$(findstring GDC,$(HOST_DMD_VERSION)))
	HOST_DMD_KIND=gdc
	HOST_DMD_VERNUM=2
endif
ifneq (,$(findstring gdc,$(HOST_DMD_VERSION))$(findstring gdmd,$(HOST_DMD_VERSION)))
	HOST_DMD_KIND=gdc
	HOST_DMD_VERNUM=2
endif
ifneq (,$(findstring ldc,$(HOST_DMD_VERSION))$(findstring LDC,$(HOST_DMD_VERSION)))
	HOST_DMD_KIND=ldc
	HOST_DMD_VERNUM=2
endif

# Compiler Warnings
ifdef ENABLE_WARNINGS
WARNINGS := -Wall -Wextra -Werror \
	-Wno-attributes \
	-Wno-char-subscripts \
	-Wno-deprecated \
	-Wno-empty-body \
	-Wno-format \
	-Wno-missing-braces \
	-Wno-missing-field-initializers \
	-Wno-overloaded-virtual \
	-Wno-parentheses \
	-Wno-reorder \
	-Wno-return-type \
	-Wno-sign-compare \
	-Wno-strict-aliasing \
	-Wno-switch \
	-Wno-type-limits \
	-Wno-unknown-pragmas \
	-Wno-unused-function \
	-Wno-unused-label \
	-Wno-unused-parameter \
	-Wno-unused-value \
	-Wno-unused-variable
# GCC Specific
ifeq ($(CXX_KIND), g++)
WARNINGS += \
	-Wno-logical-op \
	-Wno-narrowing \
	-Wno-unused-but-set-variable \
	-Wno-uninitialized \
	-Wno-class-memaccess \
	-Wno-implicit-fallthrough
endif
else
# Default Warnings
WARNINGS := -Wno-deprecated -Wstrict-aliasing -Werror
# Clang Specific
ifeq ($(CXX_KIND), clang++)
WARNINGS += \
    -Wno-logical-op-parentheses
endif
endif

OS_UPCASE := $(shell echo $(OS) | tr '[a-z]' '[A-Z]')

# Default compiler flags for all source files
CXXFLAGS := $(WARNINGS) \
	-fno-exceptions -fno-rtti \
	-D__pascal= -DMARS=1 -DTARGET_$(OS_UPCASE)=1 -DDM_TARGET_CPU_$(TARGET_CPU)=1 \
	$(MODEL_FLAG) $(PIC) -DDMD_VERSION=$(HOST_DMD_VERNUM)
# GCC Specific
ifeq ($(CXX_KIND), g++)
CXXFLAGS += \
    -std=gnu++98
endif
# Clang Specific
ifeq ($(CXX_KIND), clang++)
CXXFLAGS += \
    -xc++
endif

DFLAGS=
override DFLAGS += -version=MARS $(PIC) -J$G
# Enable D warnings
override DFLAGS += -w -de

# Append different flags for debugging, profiling and release.
ifdef ENABLE_DEBUG
CXXFLAGS += -g -g3 -DDEBUG=1 -DUNITTEST
override DFLAGS += -g -debug
endif
ifdef ENABLE_RELEASE
CXXFLAGS += -O2
override DFLAGS += -O -release -inline
else
# Add debug symbols for all non-release builds
override DFLAGS += -g
endif
ifdef ENABLE_PROFILING
CXXFLAGS  += -pg -fprofile-arcs -ftest-coverage
endif
ifdef ENABLE_PGO_GENERATE
CXXFLAGS  += -fprofile-generate=${PGO_DIR}
endif
ifdef ENABLE_PGO_USE
CXXFLAGS  += -fprofile-use=${PGO_DIR} -freorder-blocks-and-partition
endif
ifdef ENABLE_LTO
CXXFLAGS  += -flto
endif
ifdef ENABLE_UNITTEST
override DFLAGS  += -unittest -cov
endif
ifdef ENABLE_PROFILE
override DFLAGS  += -profile
endif
ifdef ENABLE_COVERAGE
ifeq ($(OS),osx)
# OSX uses libclang_rt.profile_osx for coverage, not libgcov
# Attempt to find it by parsing `clang`'s output
CLANG_LIB_SEARCH_DIR := $(shell clang -print-search-dirs | grep libraries | cut -d= -f2)
COVERAGE_LINK_FLAGS := -L-L$(CLANG_LIB_SEARCH_DIR)/lib/darwin/ -L-lclang_rt.profile_osx
else
COVERAGE_LINK_FLAGS := -L-lgcov
endif
override DFLAGS  += -cov $(COVERAGE_LINK_FLAGS)
CXXFLAGS += --coverage
endif
ifdef ENABLE_SANITIZERS
CXXFLAGS += -fsanitize=${ENABLE_SANITIZERS}

ifeq ($(HOST_DMD_KIND), dmd)
HOST_CXX += -fsanitize=${ENABLE_SANITIZERS}
endif
ifneq (,$(findstring gdc,$(HOST_DMD_KIND))$(findstring ldc,$(HOST_DMD_KIND)))
override DFLAGS += -fsanitize=${ENABLE_SANITIZERS}
endif

endif

# Unique extra flags if necessary
BACK_FLAGS := -I$(ROOT) -I$C -I$G -I$D -DDMDV2=1
BACK_DFLAGS := -version=DMDV2
ROOT_FLAGS := -I$(ROOT)

ifeq ($(OS), osx)
ifeq ($(MODEL), 64)
D_OBJC := 1
endif
endif

ifneq (gdc, $(HOST_DMD_KIND))
  BACK_MV = -mv=dmd.backend=$C
# Don't enable -betterC for compiling the backend for coverage reports
ifndef ENABLE_COVERAGE
  BACK_BETTERC = $(BACK_MV) -betterC
else
  BACK_BETTERC = $(BACK_MV)
endif
  # gdmd doesn't support -dip25
  override DFLAGS  += -dip25
endif

######## Additional files

SRC_MAKE = posix.mak osmodel.mak

DEPS = $(patsubst %.o,%.deps,$(DMD_OBJS))

RUN_BUILD = $(GENERATED)/build HOST_DMD="$(HOST_DMD)" CXX="$(HOST_CXX)" OS=$(OS) BUILD=$(BUILD) MODEL=$(MODEL) AUTO_BOOTSTRAP="$(AUTO_BOOTSTRAP)" DOCDIR="$(DOCDIR)" STDDOC="$(STDDOC)" DOC_OUTPUT_DIR="$(DOC_OUTPUT_DIR)" MAKE="$(MAKE)" --called-from-make

######## Begin build targets


all: dmd
.PHONY: all

dmd: $G/dmd $G/dmd.conf
.PHONY: dmd

$(GENERATED)/build: build.d $(HOST_DMD_PATH)
	$(HOST_DMD_RUN) -of$@ build.d

auto-tester-build: dmd checkwhitespace cxx-unittest
.PHONY: auto-tester-build

toolchain-info: $(GENERATED)/build
	$(RUN_BUILD) $@

unittest: $G/dmd-unittest
	$<

######## Manual cleanup

clean:
	rm -Rf $(GENERATED)
	@[ ! -d ${PGO_DIR} ] || echo You should issue manually: rm -rf ${PGO_DIR}

######## Download and install the last dmd buildable without dmd

ifneq (,$(AUTO_BOOTSTRAP))
CURL_FLAGS:=-fsSL --retry 5 --retry-max-time 120 --connect-timeout 5 --speed-time 30 --speed-limit 1024
$(HOST_DMD_PATH):
	mkdir -p ${HOST_DMD_ROOT}
ifneq (,$(shell which xz 2>/dev/null))
	curl ${CURL_FLAGS} ${HOST_DMD_URL}.tar.xz | tar -C ${HOST_DMD_ROOT} -Jxf - || rm -rf ${HOST_DMD_ROOT}
else
	TMPFILE=$$(mktemp deleteme.XXXXXXXX) &&	curl ${CURL_FLAGS} ${HOST_DMD_URL}.zip > $${TMPFILE}.zip && \
		unzip -qd ${HOST_DMD_ROOT} $${TMPFILE}.zip && rm $${TMPFILE}.zip;
endif
endif

FORCE: ;

# Generic rules for all source files
########################################################################
# Search the directory $C for .c-files when using implicit pattern
# matching below.
#vpath %.c $C

-include $(DEPS)

################################################################################
# Generate the man pages
################################################################################

DMD_MAN_PAGE = $(GENERATED)/docs/man1/dmd.1

$(DMD_MAN_PAGE): dmd/cli.d
	${MAKE} -C ../docs DMD=$(HOST_DMD_PATH) build

man: $(DMD_MAN_PAGE)

######################################################

install: all $(DMD_MAN_PAGE)
	$(eval bin_dir=$(if $(filter $(OS),osx), bin, bin$(MODEL)))
	mkdir -p $(INSTALL_DIR)/$(OS)/$(bin_dir)
	cp $G/dmd $(INSTALL_DIR)/$(OS)/$(bin_dir)/dmd
	cp ../ini/$(OS)/$(bin_dir)/dmd.conf $(INSTALL_DIR)/$(OS)/$(bin_dir)/dmd.conf
	cp $D/boostlicense.txt $(INSTALL_DIR)/dmd-boostlicense.txt

######################################################

checkwhitespace: $(GENERATED)/build
	$(RUN_BUILD) $@

######################################################
# DScanner
######################################################

# runs static code analysis with Dscanner
style: $(GENERATED)/build
	$(RUN_BUILD) $@

######################################################

cxx-unittest: $(GENERATED)/build
	$(RUN_BUILD) $@

######################################################

zip: $(GENERATED)/build
	$(RUN_BUILD) $@

######################################################

gitzip:
	git archive --format=zip HEAD > $(ZIPFILE)

######################################################
# Default rule to forward targets to build.d

$G/%: $(GENERATED)/build FORCE
	$(RUN_BUILD) $@

################################################################################
# DDoc documentation generation
################################################################################

# BEGIN fallbacks for old variable names
# should be removed after https://github.com/dlang/dlang.org/pull/1581
# has been pulled
DOCSRC=../dlang.org
STDDOC=$(DOCFMT)
DOC_OUTPUT_DIR=$(DOCDIR)
# END fallbacks

# DDoc html generation - this is very similar to the way the documentation for
# Phobos is built
ifneq ($(DOCSRC),)

html: $(GENERATED)/build FORCE
	$(RUN_BUILD) $@

endif

######################################################

.DELETE_ON_ERROR: # GNU Make directive (delete output files on error)
