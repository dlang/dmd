# This Makefile snippet detects the OS and the architecture MODEL

ifeq (,$(OS))
  uname_S:=$(shell uname -s)
  ifeq (Darwin,$(uname_S))
    OS:=osx
  endif
  ifeq (Linux,$(uname_S))
    OS:=linux
  endif
  ifeq (FreeBSD,$(uname_S))
    OS:=freebsd
  endif
  ifeq (OpenBSD,$(uname_S))
    OS:=openbsd
  endif
  ifeq (Solaris,$(uname_S))
    OS:=solaris
  endif
  ifeq (SunOS,$(uname_S))
    OS:=solaris
  endif
  ifeq (,$(OS))
    $(error Unrecognized or unsupported OS for uname: $(uname_S))
  endif
endif

ifeq (,$(MODEL))
  uname_M:=$(shell uname -m)
  ifneq (,$(findstring $(uname_M),x86_64 amd64))
    MODEL:=64
  endif
  ifneq (,$(findstring $(uname_M),i386 i586 i686))
    MODEL:=32
  endif
  ifeq (,$(MODEL))
    $(error Cannot figure 32/64 model from uname -m: $(uname_M))
  endif
endif

MODEL_FLAG:=-m$(MODEL)
