TESTS := importc_compare

# FIXME: fails on Alpine v3.21 with conflicting struct declarations in the C headers:
# /usr/include/asm-generic/fcntl.h(195): Error: struct `importc_includes.flock` conflicts with struct `importc_includes.flock` at /usr/include/fcntl.h(24)
ifeq ($(OS),linux)
    ifeq (1,$(shell which apk &>/dev/null && echo 1))
        TESTS :=
    endif
endif

include ../common.mak

extra_dflags += -d

ifeq ($(OS),windows)
    extra_dflags += -P=/std:c11
endif
