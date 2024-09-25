TESTS:=attributes sentinel printf memstomp invariant logging \
       precise precisegc \
       recoverfree nocollect

ifneq ($(OS),windows)
    # some .d files are for Posix only
    TESTS+=sentinel1 sentinel2 forkgc forkgc2 sigmaskgc startbackgc
    # and some tests require the `fork` GC, only supported on Posix
    TESTS+=concurrent precise_concurrent hospital
endif

VALGRIND = valgrind
has_valgrind != command -v $(VALGRIND) > /dev/null 2>&1 && echo 1

ifeq ($(has_valgrind),1)
valgrind_new_enough != $(VALGRIND) --version | grep -E 'valgrind-3.([0-9]|1[012])\b' || echo 1
endif

ifeq ($(valgrind_new_enough),1)
TESTS += issue22843
endif

include ../common.mak
vpath

src_gc := ../../src/core/internal/gc/impl/conservative/gc.d
src_lifetime=$(src_gc) ../../src/rt/lifetime.d
# ../../src/object.d causes duplicate symbols
core_ut = -unittest -version=CoreUnittest

# https://issues.dlang.org/show_bug.cgi?id=22843
# needs to run under valgrind
# versions before 3.13.0 don't handle clone() correctly, skip them
$(ROOT)/issue22843.done: $(ROOT)/issue22843$(DOTEXE)
	@echo Testing $(<F:$(DOTEXE)=)
	$(TIMELIMIT)$(VALGRIND) --quiet --tool=none $(ROOT)/issue22843 $(run_args)
	@touch $@

$(ROOT)/sentinel$(DOTEXE): $(src_lifetime)
$(ROOT)/sentinel$(DOTEXE): private extra_sources = $(src_lifetime)
$(ROOT)/sentinel$(DOTEXE): extra_dflags += -debug=SENTINEL $(core_ut) -main
$(ROOT)/sentinel1$(DOTEXE): $(src_lifetime)
$(ROOT)/sentinel1$(DOTEXE): private extra_sources = $(src_lifetime)
$(ROOT)/sentinel1$(DOTEXE): extra_dflags += -debug=SENTINEL -debug=GC_RECURSIVE_LOCK
$(ROOT)/sentinel2$(DOTEXE): $(src_lifetime)
$(ROOT)/sentinel2$(DOTEXE): private extra_sources = $(src_lifetime)
$(ROOT)/sentinel2$(DOTEXE): extra_dflags += -debug=SENTINEL -debug=GC_RECURSIVE_LOCK -gx

$(ROOT)/printf$(DOTEXE): $(src_gc)
$(ROOT)/printf$(DOTEXE): private extra_sources = $(src_gc)
$(ROOT)/printf$(DOTEXE): extra_dflags += \
	-debug=PRINTF -debug=PRINTF_TO_FILE -debug=COLLECT_PRINTF $(core_ut) -main

$(ROOT)/memstomp$(DOTEXE): $(src_lifetime)
$(ROOT)/memstomp$(DOTEXE): private extra_sources = $(src_lifetime)
$(ROOT)/memstomp$(DOTEXE): extra_dflags += -debug=MEMSTOMP $(core_ut) -main

$(ROOT)/invariant$(DOTEXE): $(src_lifetime)
$(ROOT)/invariant$(DOTEXE): private extra_sources = $(src_lifetime)
$(ROOT)/invariant$(DOTEXE): extra_dflags += $(core_ut) \
    -debug -debug=INVARIANT -check=invariant -debug=PTRCHECK -debug=PTRCHECK2 -main

$(ROOT)/logging$(DOTEXE): $(src_lifetime)
$(ROOT)/logging$(DOTEXE): private extra_sources = $(src_lifetime)
$(ROOT)/logging$(DOTEXE): extra_dflags += -debug=LOGGING -main $(core_ut)

$(ROOT)/precise$(DOTEXE): $(src_lifetime)
$(ROOT)/precise$(DOTEXE): private extra_sources = $(src_lifetime)
$(ROOT)/precise$(DOTEXE): extra_dflags += $(core_ut) \
    -debug -debug=INVARIANT -check=invariant -debug=MEMSTOMP -main
$(ROOT)/precise.done: run_args += --DRT-gcopt=gc:precise

$(ROOT)/precisegc$(DOTEXE): $(src_lifetime)
$(ROOT)/precisegc$(DOTEXE): private extra_sources = $(src_lifetime)
$(ROOT)/precisegc$(DOTEXE): extra_dflags += $(core_ut) -gx

$(ROOT)/concurrent$(DOTEXE): $(src_lifetime)
$(ROOT)/concurrent$(DOTEXE): private extra_sources = $(src_lifetime)
$(ROOT)/concurrent$(DOTEXE): extra_dflags += $(core_ut) -main
$(ROOT)/concurrent.done: run_args+=--DRT-gcopt=fork:1

$(ROOT)/precise_concurrent$(DOTEXE): $(src_lifetime)
$(ROOT)/precise_concurrent$(DOTEXE): private extra_sources = $(src_lifetime)
$(ROOT)/precise_concurrent$(DOTEXE): extra_dflags += $(core_ut) -main
$(ROOT)/precise_concurrent.done: run_args+="--DRT-gcopt=gc:precise fork:1"

$(ROOT)/attributes$(DOTEXE): extra_dflags += $(core_ut)
$(ROOT)/forkgc$(DOTEXE): extra_dflags += $(core_ut)
$(ROOT)/forkgc2$(DOTEXE): extra_dflags += $(core_ut)
$(ROOT)/sigmaskgc$(DOTEXE): extra_dflags += $(core_ut)
$(ROOT)/startbackgc$(DOTEXE): extra_dflags += $(core_ut)
$(ROOT)/hospital$(DOTEXE): extra_dflags += -d
$(ROOT)/hospital.done: run_args+=--DRT-gcopt=fork:1
$(ROOT)/issue22843$(DOTEXE): extra_dflags += $(core_ut)
$(ROOT)/issue22843.done: run_args+="--DRT-gcopt=fork:1 initReserve:0 minPoolSize:1"
