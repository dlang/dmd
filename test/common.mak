# set from top makefile
OS:=
MODEL:=
BUILD:=
DMD:=
DRUNTIME:=
DRUNTIMESO:=
QUIET:=
LINKDL:=
LDL:=$(subst -L,,$(LINKDL)) # -ldl

SRC:=src
GENERATED:=./generated
ROOT:=$(GENERATED)/$(OS)/$(BUILD)/$(MODEL)

ifneq (default,$(MODEL))
	MODEL_FLAG:=-m$(MODEL)
endif
CFLAGS:=$(MODEL_FLAG) -Wall
DFLAGS:=$(MODEL_FLAG) -w -I../../src -I../../import -I$(SRC) -defaultlib= -debuglib=
# LINK_SHARED may be set by importing makefile
DFLAGS+=$(if $(LINK_SHARED),-L$(DRUNTIMESO),-L$(DRUNTIME))
ifeq ($(BUILD),debug)
	DFLAGS += -g -debug
	CFLAGS += -g
else
	DFLAGS += -O -release
	CFLAGS += -O3
endif
