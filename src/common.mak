# Common Makefile variables (shared between DMD, DRuntime and Phobos)
# Be careful when updating
# This file expects the following variables to be defined in the including Makefile:
# - D_HOME        Root of all D repositories

###############################################################################
# Common directories
################################################################################

DMD_DIR = $(D_HOME)/dmd
DRUNTIME_DIR = $(D_HOME)/druntime
PHOBOS_DIR = $(D_HOME)/phobos
DLANG_ORG_DIR = $(D_HOME)/dlang.org
TOOLS_DIR = $(D_HOME)/tools
INSTALL_DIR = $(D_HOME)/install
INSTALLER_DIR = $(D_HOME)/installer
TMP?=/tmp
GIT_HOME=https://github.com/dlang

# get OS and MODEL
include $(D_HOME)/dmd/src/osmodel.mak

###############################################################################
# Common variables
################################################################################

# Set VERSION, where the file is that contains the version string
VERSION=$(DMD_DIR)/VERSION
MAKEFILE = $(firstword $(MAKEFILE_LIST))

################################################################################
# Output directories
################################################################################

DMD_GENERATED=$(DMD_DIR)/generated
DRUNTIME_GENERATED=$(DRUNTIME_DIR)/generated
PHOBOS_GENERATED=$(PHOBOS_DIR)/generated

BUILD_TRIPLE=$(OS)/$(BUILD)/$(MODEL)

DMD_BUILD_DIR=$(DMD_GENERATED)/$(BUILD_TRIPLE)
DRUNTIME_BUILD_DIR=$(DRUNTIME_GENERATED)/$(BUILD_TRIPLE)
PHOBOS_BUILD_DIR=$(PHOBOS_GENERATED)/$(BUILD_TRIPLE)

################################################################################
# Detect build mode (default: release)
################################################################################

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

################################################################################
# Target-specific flags
################################################################################

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


ifeq (osx,$(OS))
    export MACOSX_DEPLOYMENT_TARGET=10.7
endif

################################################################################
# Define library files and import paths
################################################################################

DRUNTIME_IMPORT_DIR=$(DRUNTIME_DIR)/import
PHOBOS_IMPORT_DIR=$(PHOBOS_DIR)

ifneq (,$(DRUNTIME))
	CUSTOM_DRUNTIME=1
endif

ifeq (,$(findstring win,$(OS)))
   LIB_DRUNTIME = $(DRUNTIME_BUILD_DIR)/libdruntime.a
   LIB_DRUNTIMESO = $(basename $(LIB_DRUNTIME)).so.a
else
   LIB_DRUNTIME = $(DRUNTIME_PATH)/lib/druntime.lib
endif

# Set PHOBOS name and full path
ifeq (,$(findstring win,$(OS)))
	LIB_PHOBOS = $(PHOBOS_BUILD_DIR)/libphobos2.a
	LIB_PHOBOSSO = $(PHOBOS_BUILD_DIR)/libphobos2.so
endif

# build with shared library support
# (defaults to true on supported platforms, can be overridden w/ make SHARED=0)
SHARED=$(if $(findstring $(OS),linux freebsd),1,)
LINKDL=$(if $(findstring $(OS),linux),-L-ldl,)

################################################################################
# Set CC and DMD
################################################################################

ifeq ($(OS),win32wine)
	CC = wine dmc.exe
	DMD = wine dmd.exe
	RUN = wine
else
	DMD = $(DMD_BUILD_DIR)/dmd
	ifeq ($(OS),win32)
		CC = dmc
	else
		CC = cc
	endif
	RUN =
endif

################################################################################
# Commonly used binaries
################################################################################

DUB=dub

################################################################################
# Platform-specific variables
################################################################################

# Set DOTOBJ and DOTEXE
ifeq (,$(findstring win,$(OS)))
	DOTOBJ:=.o
	DOTEXE:=
	PATHSEP:=/
else
	DOTOBJ:=.obj
	DOTEXE:=.exe
	PATHSEP:=$(shell echo "\\")
endif

ifeq (osx,$(OS))
	DOTDLL:=.dylib
	DOTLIB:=.a
else
	DOTDLL:=.so
	DOTLIB:=.a
endif

################################################################################
# Phobos DFLAGS (for linking with the currently built Phobos)
################################################################################

PHOBOS_DFLAGS=-conf= $(MODEL_FLAG) -I$(DRUNTIME_IMPORT_DIR) -I$(PHOBOS_IMPORT_DIR) -L-L$(PHOBOS_BUILD_DIR) $(PIC)
ifeq (1,$(SHARED))
PHOBOS_DFLAGS+=-defaultlib=libphobos2.so -L-rpath=$(PHOBOS_BUILD_DIR)
endif

################################################################################
# Default DUB FLAGS
################################################################################

DUBFLAGS = --arch=$(subst 32,x86,$(subst 64,x86_64,$(MODEL)))

################################################################################
# Automatically create dlang/tools repository if non-existent
################################################################################

_all: all

$(TOOLS_DIR):
	git clone --depth=1 ${GIT_HOME}/$(@F) $@

$(TOOLS_DIR)/checkwhitespace.d: | $(TOOLS_DIR)


################################################################################
# Common build rules
#
# Use _build to avoid conflicts with their real rules
################################################################################

$(DMD)_build: $(DMD)
	make -C $(DMD_DIR)/src -f posix.mak BUILD=$(BUILD) OS=$(OS) MODEL=$(MODEL)
	touch $@

$(LIB_DRUNTIME)_build: $(LIB_DRUNTIME)
	make -C $(DRUNTIME_DIR) -f posix.mak BUILD=$(BUILD) OS=$(OS) MODEL=$(MODEL)
	touch $@

ifeq (,$(findstring win,$(OS)))
$(LIB_DRUNTIMESO)_build: $(LIB_DRUNTIME)_build
endif
