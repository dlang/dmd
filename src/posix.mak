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
# ENABLE_RELEASE:       Optimized release build
# ENABLE_DEBUG:         Add debug instructions and symbols (set if ENABLE_RELEASE isn't set)
# ENABLE_ASSERTS:       Don't use -release if ENABLE_RELEASE is set
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

$(warning ===== DEPRECATION NOTICE ===== )
$(warning ===== DEPRECATION: posix.mak is deprecated. Please use src/build.d instead.)
$(warning ============================== )

# Forward D compiler bootstrapping to bootstrap.sh
ifneq (,$(AUTO_BOOTSTRAP))
default:
	@./bootstrap.sh
.DEFAULT:
	@./bootstrap.sh "$@"
else

# get OS and MODEL
include osmodel.mak

# Default to a release built, override with BUILD=debug
ifeq (,$(BUILD))
BUILD=release
endif

ifneq ($(BUILD),release)
    ifneq ($(BUILD),debug)
        $(error Unrecognized BUILD=$(BUILD), must be 'debug' or 'release')
    endif
endif

INSTALL_DIR=../../install
D = dmd

GENERATED = ../generated
G = $(GENERATED)/$(OS)/$(BUILD)/$(MODEL)
$(shell mkdir -p $G)

ifeq (osx,$(OS))
    export MACOSX_DEPLOYMENT_TARGET=10.9
endif

HOST_CXX?=c++
# compatibility with old behavior
ifneq ($(HOST_CC),)
  $(warning ===== WARNING: Please use HOST_CXX=$(HOST_CC) instead of HOST_CC=$(HOST_CC). =====)
  HOST_CXX=$(HOST_CC)
endif

HOST_DC?=
ifneq (,$(HOST_DC))
  $(warning ========== Use HOST_DMD instead of HOST_DC ========== )
  HOST_DMD=$(HOST_DC)
endif

# No bootstrap, a $(HOST_DMD) installation must be available
HOST_DMD?=dmd
HOST_DMD_PATH=$(abspath $(shell which $(HOST_DMD)))
ifeq (,$(HOST_DMD_PATH))
  $(error '$(HOST_DMD)' not found, get a D compiler or make AUTO_BOOTSTRAP=1)
endif
HOST_DMD_RUN:=$(HOST_DMD)

RUN_BUILD = $(GENERATED)/build OS="$(OS)" BUILD="$(BUILD)" MODEL="$(MODEL)" HOST_DMD="$(HOST_DMD)" CXX="$(HOST_CXX)" AUTO_BOOTSTRAP="$(AUTO_BOOTSTRAP)" DOCDIR="$(DOCDIR)" STDDOC="$(STDDOC)" DOC_OUTPUT_DIR="$(DOC_OUTPUT_DIR)" MAKE="$(MAKE)" VERBOSE="$(VERBOSE)" ENABLE_RELEASE="$(ENABLE_RELEASE)" ENABLE_DEBUG="$(ENABLE_DEBUG)" ENABLE_ASSERTS="$(ENABLE_ASSERTS)" ENABLE_UNITTEST="$(ENABLE_UNITTEST)" ENABLE_PROFILE="$(ENABLE_PROFILE)" ENABLE_COVERAGE="$(ENABLE_COVERAGE)" DFLAGS="$(DFLAGS)"
######## Begin build targets

all: dmd
.PHONY: all

dmd: $(GENERATED)/build
	$(RUN_BUILD) $@
.PHONY: dmd

$(GENERATED)/build: build.d $(HOST_DMD_PATH)
	$(HOST_DMD_RUN) -of$@ -g build.d

auto-tester-build: $(GENERATED)/build
	$(RUN_BUILD) $@

.PHONY: auto-tester-build

toolchain-info: $(GENERATED)/build
	$(RUN_BUILD) $@

# Run header test on linux
ifeq ($(OS)$(MODEL),linux64)
  HEADER_TEST=cxx-headers-test
endif

auto-tester-test: $(GENERATED)/build
	$(RUN_BUILD) unittest $(HEADER_TEST)

unittest: $(GENERATED)/build
	$(RUN_BUILD) $@

######## Manual cleanup

clean:
	rm -Rf $(GENERATED)

FORCE: ;

################################################################################
# Generate the man pages
################################################################################

DMD_MAN_PAGE = $(GENERATED)/docs/man/man1/dmd.1

$(GENERATED)/docs/%: $(GENERATED)/build
	$(RUN_BUILD) $@

man: $(GENERATED)/build
	$(RUN_BUILD) $@

######################################################

install: $(GENERATED)/build $(DMD_MAN_PAGE)
	$(RUN_BUILD) $@

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

# Dont run targets in parallel because this makefile is just a thin wrapper
# for build.d and multiple invocations might stomp on each other.
# (build.d employs it's own parallelization)
.NOTPARALLEL:

endif
