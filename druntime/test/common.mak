# set explicitly in the make cmdline in druntime/Makefile (`test/%/.run` rule):
OS:=
MODEL:=
BUILD:=
DMD:=
DRUNTIME:=
DRUNTIMESO:=
LINKDL:=
QUIET:=
TIMELIMIT:=
PIC:=

# Windows: set up bash shell
ifeq (windows,$(OS))
    include ../../../compiler/src/osmodel.mak
endif

LDL:=$(subst -L,,$(LINKDL)) # -ldl
SRC:=src
GENERATED:=./generated
ROOT:=$(GENERATED)/$(OS)/$(BUILD)/$(MODEL)
DRUNTIME_IMPLIB:=$(subst .dll,.lib,$(DRUNTIMESO))

MODEL_FLAG:=$(if $(findstring $(MODEL),default),,-m$(MODEL))
CFLAGS_BASE:=$(if $(findstring $(OS),windows),/Wall,$(MODEL_FLAG) $(PIC) -Wall)
ifeq (osx64,$(OS)$(MODEL))
    CFLAGS_BASE+=--target=x86_64-darwin-apple  # ARM cpu is not supported by dmd
endif
DFLAGS:=$(MODEL_FLAG) $(PIC) -w -I../../src -I../../import -I$(SRC) -defaultlib= -preview=dip1000 $(if $(findstring $(OS),windows),,-L-lpthread -L-lm $(LINKDL))
# LINK_SHARED may be set by importing makefile
DFLAGS+=$(if $(LINK_SHARED),-L$(DRUNTIME_IMPLIB) $(if $(findstring $(OS),windows),-dllimport=defaultLibsOnly),-L$(DRUNTIME))
ifeq ($(BUILD),debug)
    DFLAGS+=-g -debug
    CFLAGS:=$(CFLAGS_BASE) $(if $(findstring $(OS),windows),/Zi,-g)
else
    DFLAGS+=-O -release
    CFLAGS:=$(CFLAGS_BASE) $(if $(findstring $(OS),windows),/O2,-O3)
endif
CXXFLAGS_BASE:=$(CFLAGS_BASE)
CXXFLAGS:=$(CFLAGS)

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
