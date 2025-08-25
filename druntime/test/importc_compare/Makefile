TESTS := importc_compare

# FIXME: fails on Alpine v3.21 with conflicting struct declarations in the C headers:
# /usr/include/asm-generic/fcntl.h(195): Error: struct `importc_includes.flock` conflicts with struct `importc_includes.flock` at /usr/include/fcntl.h(24)
ifeq ($(IS_MUSL),1)
    TESTS :=
endif

include ../common.mak

extra_dflags += -d
