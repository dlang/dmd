# set from top makefile
OS:=
MODEL:=
BUILD:=
DMD:=
DRUNTIME:=
DRUNTIMESO:=
LINKDL:=
QUIET:=
TIMELIMIT:=
LDL:=$(subst -L,,$(LINKDL)) # -ldl

SRC:=src
GENERATED:=./generated
ROOT:=$(GENERATED)/$(OS)/$(BUILD)/$(MODEL)

# -fPIC is enabled by default and can be disabled with DISABLE_PIC=1
ifeq (,$(DISABLE_PIC))
    PIC_FLAG:=-fPIC
else
    PIC_FLAG:=
endif

ifneq (default,$(MODEL))
	MODEL_FLAG:=-m$(MODEL)
endif
CFLAGS:=$(MODEL_FLAG) -Wall
DFLAGS:=$(MODEL_FLAG) -w -I../../src -I../../import -I$(SRC) -defaultlib= -debuglib= -dip1000 $(PIC_FLAG)
# LINK_SHARED may be set by importing makefile
DFLAGS+=$(if $(LINK_SHARED),-L$(DRUNTIMESO),-L$(DRUNTIME))
ifeq ($(BUILD),debug)
	DFLAGS += -g -debug
	CFLAGS += -g
else
	DFLAGS += -O -release
	CFLAGS += -O3
endif
