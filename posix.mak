
DMD=dmd

DOCDIR=doc
IMPDIR=import

MODEL=32

DFLAGS=-m$(MODEL) -release -inline -nofloat -w -d -Isrc -Iimport
UDFLAGS=-m$(MODEL) -release -nofloat -w -d -Isrc -Iimport

CFLAGS=-m$(MODEL) -g

OBJDIR=obj
DRUNTIME_BASE=druntime
DRUNTIME=lib/lib$(DRUNTIME_BASE).a

DOCFMT=

target : import $(DRUNTIME) doc

_MISSING_FROM_MANIFEST = \
	src/core/sys/posix/sys/select \
	src/core/sys/posix/sys/socket \
	src/core/sys/posix/sys/stat \
	src/core/sys/posix/sys/wait \
	src/core/sys/posix/netinet/in_

MANIFEST= \
	LICENSE_1_0.txt \
	README.txt \
	posix.mak \
	win32.mak \
	\
	import/object.di \
	import/std/intrinsic.di \
	\
	$(addprefix src,$(addsuffix .d,$(SRC_D_MODULES))) \
	\
	src/core/dll_helper.d \
	src/core/thread_helper.d \
	src/core/threadasm.S \
	\
	src/core/stdc/complex.d \
	src/core/stdc/errno.c \
	src/core/stdc/fenv.d \
	src/core/stdc/float_.d \
	src/core/stdc/inttypes.d \
	src/core/stdc/limits.d \
	src/core/stdc/locale.d \
	src/core/stdc/tgmath.d \
	src/core/stdc/wctype.d \
	\
	src/core/sys/osx/mach/dyld.d \
	src/core/sys/osx/mach/getsect.d \
	src/core/sys/osx/mach/kern_return.d \
	src/core/sys/osx/mach/loader.d \
	src/core/sys/osx/mach/port.d \
	src/core/sys/osx/mach/semaphore.d \
	src/core/sys/osx/mach/thread_act.d \
	\
	src/core/sys/posix/config.d \
	src/core/sys/posix/dirent.d \
	src/core/sys/posix/dlfcn.d \
	src/core/sys/posix/fcntl.d \
	src/core/sys/posix/inttypes.d \
	src/core/sys/posix/net/if_.d \
	src/core/sys/posix/poll.d \
	src/core/sys/posix/pthread.d \
	src/core/sys/posix/pwd.d \
	src/core/sys/posix/sched.d \
	src/core/sys/posix/semaphore.d \
	src/core/sys/posix/setjmp.d \
	src/core/sys/posix/signal.d \
	src/core/sys/posix/stdio.d \
	src/core/sys/posix/stdlib.d \
	src/core/sys/posix/termios.d \
	src/core/sys/posix/time.d \
	src/core/sys/posix/ucontext.d \
	src/core/sys/posix/unistd.d \
	src/core/sys/posix/utime.d \
	\
	src/core/sys/posix/arpa/inet.d \
	\
	src/core/sys/posix/netinet/in_.d \
	src/core/sys/posix/netinet/tcp.d \
	\
	src/core/sys/posix/sys/ipc.d \
	src/core/sys/posix/sys/mman.d \
	src/core/sys/posix/sys/select.d \
	src/core/sys/posix/sys/shm.d \
	src/core/sys/posix/sys/socket.d \
	src/core/sys/posix/sys/stat.d \
	src/core/sys/posix/sys/time.d \
	src/core/sys/posix/sys/types.d \
	src/core/sys/posix/sys/uio.d \
	src/core/sys/posix/sys/wait.d \
	\
	src/core/sys/windows/windows.d \
	\
	src/gcstub/gc.d \
	\
	src/rt/compiler.d \
	src/rt/complex.c \
	src/rt/critical.c \
	src/rt/deh.c \
	src/rt/dylib_fixes.c \
	src/rt/image.d \
	src/rt/mars.h \
	src/rt/memory_osx.c \
	src/rt/minit.asm \
	src/rt/monitor.c \
	src/rt/qsort2.d \
	src/rt/tls.S

SRC_D_MODULES = \
	object_ \
	\
	core/atomic \
	core/bitop \
	core/cpuid \
	core/demangle \
	core/exception \
	core/memory \
	core/runtime \
	core/thread \
	core/time \
	core/vararg \
	\
	core/stdc/config \
	core/stdc/ctype \
	core/stdc/errno \
	core/stdc/math \
	core/stdc/signal \
	core/stdc/stdarg \
	core/stdc/stdio \
	core/stdc/stdlib \
	core/stdc/stdint \
	core/stdc/stddef \
	core/stdc/string \
	core/stdc/time \
	core/stdc/wchar_ \
	\
	core/sys/posix/sys/select \
	core/sys/posix/sys/socket \
	core/sys/posix/sys/stat \
	core/sys/posix/sys/wait \
	core/sys/posix/netinet/in_ \
	\
	core/sync/barrier \
	core/sync/condition \
	core/sync/config \
	core/sync/exception \
	core/sync/mutex \
	core/sync/rwmutex \
	core/sync/semaphore \
	\
	gc/gc \
	gc/gcalloc \
	gc/gcbits \
	gc/gcstats \
	gc/gcx \
	\
	rt/aaA \
	rt/aApply \
	rt/aApplyR \
	rt/adi \
	rt/alloca \
	rt/arrayassign \
	rt/arraybyte \
	rt/arraycast \
	rt/arraycat \
	rt/arraydouble \
	rt/arrayfloat \
	rt/arrayint \
	rt/arrayreal \
	rt/arrayshort \
	rt/cast_ \
	rt/cmath2 \
	rt/cover \
	rt/deh2 \
	rt/dmain2 \
	rt/invariant \
	rt/invariant_ \
	rt/lifetime \
	rt/llmath \
	rt/memory \
	rt/memset \
	rt/obj \
	rt/qsort \
	rt/switch_ \
	rt/trace \
	\
	rt/util/console \
	rt/util/ctype \
	rt/util/hash \
	rt/util/string \
	rt/util/utf \
	\
	rt/typeinfo/ti_AC \
	rt/typeinfo/ti_Acdouble \
	rt/typeinfo/ti_Acfloat \
	rt/typeinfo/ti_Acreal \
	rt/typeinfo/ti_Adouble \
	rt/typeinfo/ti_Afloat \
	rt/typeinfo/ti_Ag \
	rt/typeinfo/ti_Aint \
	rt/typeinfo/ti_Along \
	rt/typeinfo/ti_Areal \
	rt/typeinfo/ti_Ashort \
	rt/typeinfo/ti_byte \
	rt/typeinfo/ti_C \
	rt/typeinfo/ti_cdouble \
	rt/typeinfo/ti_cfloat \
	rt/typeinfo/ti_char \
	rt/typeinfo/ti_creal \
	rt/typeinfo/ti_dchar \
	rt/typeinfo/ti_delegate \
	rt/typeinfo/ti_double \
	rt/typeinfo/ti_float \
	rt/typeinfo/ti_idouble \
	rt/typeinfo/ti_ifloat \
	rt/typeinfo/ti_int \
	rt/typeinfo/ti_ireal \
	rt/typeinfo/ti_long \
	rt/typeinfo/ti_ptr \
	rt/typeinfo/ti_real \
	rt/typeinfo/ti_short \
	rt/typeinfo/ti_ubyte \
	rt/typeinfo/ti_uint \
	rt/typeinfo/ti_ulong \
	rt/typeinfo/ti_ushort \
	rt/typeinfo/ti_void \
	rt/typeinfo/ti_wchar

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for Linux

OBJS= $(OBJDIR)/errno_c.o $(OBJDIR)/threadasm.o $(OBJDIR)/complex.o	\
$(OBJDIR)/critical.o $(OBJDIR)/memory_osx.o $(OBJDIR)/monitor.o

DOCS=\
	$(DOCDIR)/object.html \
	$(DOCDIR)/core_atomic.html \
	$(DOCDIR)/core_bitop.html \
	$(DOCDIR)/core_cpuid.html \
	$(DOCDIR)/core_demangle.html \
	$(DOCDIR)/core_exception.html \
	$(DOCDIR)/core_memory.html \
	$(DOCDIR)/core_runtime.html \
	$(DOCDIR)/core_thread.html \
	$(DOCDIR)/core_time.html \
	$(DOCDIR)/core_vararg.html \
	\
	$(DOCDIR)/core_sync_barrier.html \
	$(DOCDIR)/core_sync_condition.html \
	$(DOCDIR)/core_sync_config.html \
	$(DOCDIR)/core_sync_exception.html \
	$(DOCDIR)/core_sync_mutex.html \
	$(DOCDIR)/core_sync_rwmutex.html \
	$(DOCDIR)/core_sync_semaphore.html

IMPORTS=\
	$(IMPDIR)/core/atomic.di \
	$(IMPDIR)/core/bitop.di \
	$(IMPDIR)/core/cpuid.di \
	$(IMPDIR)/core/demangle.di \
	$(IMPDIR)/core/dll_helper.di \
	$(IMPDIR)/core/exception.di \
	$(IMPDIR)/core/memory.di \
	$(IMPDIR)/core/runtime.di \
	$(IMPDIR)/core/thread.di \
	$(IMPDIR)/core/time.di \
	$(IMPDIR)/core/thread_helper.di \
	$(IMPDIR)/core/vararg.di \
	\
	$(IMPDIR)/core/stdc/complex.di \
	$(IMPDIR)/core/stdc/config.di \
	$(IMPDIR)/core/stdc/ctype.di \
	$(IMPDIR)/core/stdc/errno.di \
	$(IMPDIR)/core/stdc/fenv.di \
	$(IMPDIR)/core/stdc/float_.di \
	$(IMPDIR)/core/stdc/inttypes.di \
	$(IMPDIR)/core/stdc/limits.di \
	$(IMPDIR)/core/stdc/locale.di \
	$(IMPDIR)/core/stdc/math.di \
	$(IMPDIR)/core/stdc/signal.di \
	$(IMPDIR)/core/stdc/stdarg.di \
	$(IMPDIR)/core/stdc/stddef.di \
	$(IMPDIR)/core/stdc/stdint.di \
	$(IMPDIR)/core/stdc/stdio.di \
	$(IMPDIR)/core/stdc/stdlib.di \
	$(IMPDIR)/core/stdc/string.di \
	$(IMPDIR)/core/stdc/tgmath.di \
	$(IMPDIR)/core/stdc/time.di \
	$(IMPDIR)/core/stdc/wchar_.di \
	$(IMPDIR)/core/stdc/wctype.di \
	\
	$(IMPDIR)/core/sync/barrier.di \
	$(IMPDIR)/core/sync/condition.di \
	$(IMPDIR)/core/sync/config.di \
	$(IMPDIR)/core/sync/exception.di \
	$(IMPDIR)/core/sync/mutex.di \
	$(IMPDIR)/core/sync/rwmutex.di \
	$(IMPDIR)/core/sync/semaphore.di \
	\
	$(IMPDIR)/core/sys/osx/mach/kern_return.di \
	$(IMPDIR)/core/sys/osx/mach/port.di \
	$(IMPDIR)/core/sys/osx/mach/semaphore.di \
	$(IMPDIR)/core/sys/osx/mach/thread_act.di \
	\
	$(IMPDIR)/core/sys/posix/arpa/inet.di \
	$(IMPDIR)/core/sys/posix/config.di \
	$(IMPDIR)/core/sys/posix/dirent.di \
	$(IMPDIR)/core/sys/posix/dlfcn.di \
	$(IMPDIR)/core/sys/posix/fcntl.di \
	$(IMPDIR)/core/sys/posix/inttypes.di \
	$(IMPDIR)/core/sys/posix/poll.di \
	$(IMPDIR)/core/sys/posix/pthread.di \
	$(IMPDIR)/core/sys/posix/pwd.di \
	$(IMPDIR)/core/sys/posix/sched.di \
	$(IMPDIR)/core/sys/posix/semaphore.di \
	$(IMPDIR)/core/sys/posix/setjmp.di \
	$(IMPDIR)/core/sys/posix/signal.di \
	$(IMPDIR)/core/sys/posix/stdio.di \
	$(IMPDIR)/core/sys/posix/stdlib.di \
	$(IMPDIR)/core/sys/posix/termios.di \
	$(IMPDIR)/core/sys/posix/time.di \
	$(IMPDIR)/core/sys/posix/ucontext.di \
	$(IMPDIR)/core/sys/posix/unistd.di \
	$(IMPDIR)/core/sys/posix/utime.di \
	\
	$(IMPDIR)/core/sys/posix/net/if_.di \
	\
	$(IMPDIR)/core/sys/posix/netinet/in_.di \
	$(IMPDIR)/core/sys/posix/netinet/tcp.di \
	\
	$(IMPDIR)/core/sys/posix/sys/ipc.di \
	$(IMPDIR)/core/sys/posix/sys/mman.di \
	$(IMPDIR)/core/sys/posix/sys/select.di \
	$(IMPDIR)/core/sys/posix/sys/shm.di \
	$(IMPDIR)/core/sys/posix/sys/socket.di \
	$(IMPDIR)/core/sys/posix/sys/stat.di \
	$(IMPDIR)/core/sys/posix/sys/time.di \
	$(IMPDIR)/core/sys/posix/sys/types.di \
	$(IMPDIR)/core/sys/posix/sys/uio.di \
	$(IMPDIR)/core/sys/posix/sys/wait.di \
	\
	$(IMPDIR)/core/sys/windows/windows.di

SRCS=$(addprefix src/,$(addsuffix .d,$(SRC_D_MODULES)))

######################## Doc .html file generation ##############################

doc: $(DOCS)

$(DOCDIR)/object.html : src/object_.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $<

$(DOCDIR)/core_%.html : src/core/%.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $<
	
$(DOCDIR)/core_sync_%.html : src/core/sync/%.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $<

######################## Header .di file generation ##############################

import: $(IMPORTS)
	
$(IMPDIR)/core/%.di : src/core/%.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $<

################### C/ASM Targets ############################

$(OBJDIR)/%.o : src/rt/%.c
	@mkdir -p $(OBJDIR)
	$(CC) -c $(CFLAGS) $< -o$@

$(OBJDIR)/errno_c.o : src/core/stdc/errno.c
	@mkdir -p $(OBJDIR)
	$(CC) -c $(CFLAGS) $< -o$@

$(OBJDIR)/threadasm.o : src/core/threadasm.S
	@mkdir -p $(OBJDIR)
	$(CC) -c $(CFLAGS) $< -o$@

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) win32.mak
	$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

unittest : $(addprefix $(OBJDIR)/,$(SRC_D_MODULES)) $(DRUNTIME) $(OBJDIR)/emptymain.d
	@echo done

ifeq ($(MODEL),64)
DISABLED_TESTS = \
	core/sync/barrier \
	core/sync/condition \
	core/sync/mutex \
	core/sync/rwmutex \
	core/sync/semaphore \
	rt/aApplyR \
	rt/dmain2 \
	rt/trace
else
DISABLED_TESTS = \
	rt/dmain2
endif

$(addprefix $(OBJDIR)/,$(DISABLED_TESTS)) :
	@echo $@ - disabled

$(OBJDIR)/% : src/%.d $(DRUNTIME) $(OBJDIR)/emptymain.d
	@echo Testing $@
	@$(DMD) $(UDFLAGS) -unittest -of$@ $(OBJDIR)/emptymain.d $< -L-Llib -debuglib=$(DRUNTIME_BASE) -defaultlib=$(DRUNTIME_BASE)
# make the file very old so it builds and runs again if it fails
	@touch -t 197001230123 $@
# run unittest in its own directory
	@$(RUN) $@
# succeeded, render the file new again
	@touch $@

$(OBJDIR)/emptymain.d :
	@mkdir -p $(OBJDIR)
	@echo 'void main(){}' >$@

zip: druntime.zip

druntime.zip:
	rm $@
	zip -u $@ $(MANIFEST) $(DOCS) $(IMPORTS) minit.o

install: druntime.zip
	unzip -o druntime.zip -d /dmd2/src/druntime

clean:
	rm -f $(DOCS) $(DRUNTIME)
	rm -rf $(OBJDIR) import/core

