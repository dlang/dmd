
DMD=dmd

DOCDIR=doc
IMPDIR=import

DFLAGS=-O -release -nofloat -w -d -Iimport -Isrc
UDFLAGS=-O -release -nofloat -w -d -Iimport -Isrc

CFLAGS=-m32 -O

OBJDIR=obj
DRUNTIME=lib/libdruntime.a

target : import $(DRUNTIME) doc

MANIFEST= \
	LICENSE_1_0.txt \
	README.txt \
	posix.mak \
	win32.mak \
	import/core/bitop.di \
	import/core/stdc/complex.d \
	import/core/stdc/config.d \
	import/core/stdc/ctype.d \
	import/core/stdc/errno.d \
	import/core/stdc/fenv.d \
	import/core/stdc/float_.d \
	import/core/stdc/inttypes.d \
	import/core/stdc/limits.d \
	import/core/stdc/locale.d \
	import/core/stdc/math.d \
	import/core/stdc/signal.d \
	import/core/stdc/stdarg.d \
	import/core/stdc/stddef.d \
	import/core/stdc/stdint.d \
	import/core/stdc/stdio.d \
	import/core/stdc/stdlib.d \
	import/core/stdc/string.d \
	import/core/stdc/tgmath.d \
	import/core/stdc/time.d \
	import/core/stdc/wchar_.d \
	import/core/stdc/wctype.d \
	import/core/sys/osx/mach/kern_return.d \
	import/core/sys/osx/mach/port.d \
	import/core/sys/osx/mach/semaphore.d \
	import/core/sys/osx/mach/thread_act.d \
	import/core/sys/posix/arpa/inet.d \
	import/core/sys/posix/config.d \
	import/core/sys/posix/dirent.d \
	import/core/sys/posix/dlfcn.d \
	import/core/sys/posix/fcntl.d \
	import/core/sys/posix/inttypes.d \
	import/core/sys/posix/net/if_.d \
	import/core/sys/posix/netinet/in_.d \
	import/core/sys/posix/netinet/tcp.d \
	import/core/sys/posix/poll.d \
	import/core/sys/posix/pthread.d \
	import/core/sys/posix/pwd.d \
	import/core/sys/posix/sched.d \
	import/core/sys/posix/semaphore.d \
	import/core/sys/posix/setjmp.d \
	import/core/sys/posix/signal.d \
	import/core/sys/posix/stdio.d \
	import/core/sys/posix/stdlib.d \
	import/core/sys/posix/sys/ipc.d \
	import/core/sys/posix/sys/mman.d \
	import/core/sys/posix/sys/select.d \
	import/core/sys/posix/sys/shm.d \
	import/core/sys/posix/sys/socket.d \
	import/core/sys/posix/sys/stat.d \
	import/core/sys/posix/sys/time.d \
	import/core/sys/posix/sys/types.d \
	import/core/sys/posix/sys/uio.d \
	import/core/sys/posix/sys/wait.d \
	import/core/sys/posix/termios.d \
	import/core/sys/posix/time.d \
	import/core/sys/posix/ucontext.d \
	import/core/sys/posix/unistd.d \
	import/core/sys/posix/utime.d \
	import/core/sys/windows/windows.d \
	import/object.di \
	import/std/intrinsic.di \
	src/core/bitop.d \
	src/core/cpuid.d \
	src/core/exception.d \
	src/core/memory.d \
	src/core/runtime.d \
	src/core/stdc/errno.c \
	src/core/sync/barrier.d \
	src/core/sync/condition.d \
	src/core/sync/config.d \
	src/core/sync/exception.d \
	src/core/sync/mutex.d \
	src/core/sync/rwmutex.d \
	src/core/sync/semaphore.d \
	src/core/thread.d \
	src/core/threadasm.S \
	src/core/vararg.d \
	src/object_.d \
	src/rt/aApply.d \
	src/rt/aApplyR.d \
	src/rt/aaA.d \
	src/rt/adi.d \
	src/rt/alloca.d \
	src/rt/arrayassign.d \
	src/rt/arraybyte.d \
	src/rt/arraycast.d \
	src/rt/arraycat.d \
	src/rt/arraydouble.d \
	src/rt/arrayfloat.d \
	src/rt/arrayint.d \
	src/rt/arrayreal.d \
	src/rt/arrayshort.d \
	src/rt/cast_.d \
	src/rt/cmath2.d \
	src/rt/compiler.d \
	src/rt/complex.c \
	src/rt/cover.d \
	src/rt/critical.c \
	src/rt/deh.c \
	src/rt/deh2.d \
	src/rt/dmain2.d \
	src/rt/invariant.d \
	src/rt/invariant_.d \
	src/rt/lifetime.d \
	src/rt/llmath.d \
	src/rt/mars.h \
	src/rt/memory.d \
	src/rt/memory_osx.c \
	src/rt/memset.d \
	src/rt/minit.asm \
	src/rt/monitor.c \
	src/rt/obj.d \
	src/rt/qsort.d \
	src/rt/qsort2.d \
	src/rt/switch_.d \
	src/rt/tls.S \
	src/rt/trace.d \
	src/rt/typeinfo/ti_AC.d \
	src/rt/typeinfo/ti_Acdouble.d \
	src/rt/typeinfo/ti_Acfloat.d \
	src/rt/typeinfo/ti_Acreal.d \
	src/rt/typeinfo/ti_Adouble.d \
	src/rt/typeinfo/ti_Afloat.d \
	src/rt/typeinfo/ti_Ag.d \
	src/rt/typeinfo/ti_Aint.d \
	src/rt/typeinfo/ti_Along.d \
	src/rt/typeinfo/ti_Areal.d \
	src/rt/typeinfo/ti_Ashort.d \
	src/rt/typeinfo/ti_C.d \
	src/rt/typeinfo/ti_byte.d \
	src/rt/typeinfo/ti_cdouble.d \
	src/rt/typeinfo/ti_cfloat.d \
	src/rt/typeinfo/ti_char.d \
	src/rt/typeinfo/ti_creal.d \
	src/rt/typeinfo/ti_dchar.d \
	src/rt/typeinfo/ti_delegate.d \
	src/rt/typeinfo/ti_double.d \
	src/rt/typeinfo/ti_float.d \
	src/rt/typeinfo/ti_idouble.d \
	src/rt/typeinfo/ti_ifloat.d \
	src/rt/typeinfo/ti_int.d \
	src/rt/typeinfo/ti_ireal.d \
	src/rt/typeinfo/ti_long.d \
	src/rt/typeinfo/ti_ptr.d \
	src/rt/typeinfo/ti_real.d \
	src/rt/typeinfo/ti_short.d \
	src/rt/typeinfo/ti_ubyte.d \
	src/rt/typeinfo/ti_uint.d \
	src/rt/typeinfo/ti_ulong.d \
	src/rt/typeinfo/ti_ushort.d \
	src/rt/typeinfo/ti_void.d \
	src/rt/typeinfo/ti_wchar.d \
	src/rt/util/console.d \
	src/rt/util/ctype.d \
	src/rt/util/hash.d \
	src/rt/util/string.d \
	src/rt/util/utf.d \
	src/gc/gc.d \
	src/gc/gcalloc.d \
	src/gc/gcbits.d \
	src/gc/gcstats.d \
	src/gc/gcx.d \
	src/gcstub/gc.d

SRCS= \
	src/core/bitop.d \
	src/core/cpuid.d \
	src/core/exception.d \
	src/core/memory.d \
	src/core/runtime.d \
	src/core/thread.d \
	src/core/vararg.d \
	\
	src/core/sync/barrier.d \
	src/core/sync/condition.d \
	src/core/sync/config.d \
	src/core/sync/exception.d \
	src/core/sync/mutex.d \
	src/core/sync/rwmutex.d \
	src/core/sync/semaphore.d \
	\
	src/gc/gc.d \
	src/gc/gcalloc.d \
	src/gc/gcbits.d \
	src/gc/gcstats.d \
	src/gc/gcx.d \
	\
	src/object_.d \
	\
	src/rt/aaA.d \
	src/rt/aApply.d \
	src/rt/aApplyR.d \
	src/rt/adi.d \
	src/rt/alloca.d \
	src/rt/arrayassign.d \
	src/rt/arraybyte.d \
	src/rt/arraycast.d \
	src/rt/arraycat.d \
	src/rt/arraydouble.d \
	src/rt/arrayfloat.d \
	src/rt/arrayint.d \
	src/rt/arrayreal.d \
	src/rt/arrayshort.d \
	src/rt/cast_.d \
	src/rt/cmath2.d \
	src/rt/cover.d \
	src/rt/deh2.d \
	src/rt/dmain2.d \
	src/rt/invariant.d \
	src/rt/invariant_.d \
	src/rt/lifetime.d \
	src/rt/llmath.d \
	src/rt/memory.d \
	src/rt/memset.d \
	src/rt/obj.d \
	src/rt/qsort.d \
	src/rt/switch_.d \
	src/rt/trace.d \
	\
	src/rt/util/console.d \
	src/rt/util/ctype.d \
	src/rt/util/hash.d \
	src/rt/util/string.d \
	src/rt/util/utf.d \
	\
	src/rt/typeinfo/ti_AC.d \
	src/rt/typeinfo/ti_Acdouble.d \
	src/rt/typeinfo/ti_Acfloat.d \
	src/rt/typeinfo/ti_Acreal.d \
	src/rt/typeinfo/ti_Adouble.d \
	src/rt/typeinfo/ti_Afloat.d \
	src/rt/typeinfo/ti_Ag.d \
	src/rt/typeinfo/ti_Aint.d \
	src/rt/typeinfo/ti_Along.d \
	src/rt/typeinfo/ti_Areal.d \
	src/rt/typeinfo/ti_Ashort.d \
	src/rt/typeinfo/ti_byte.d \
	src/rt/typeinfo/ti_C.d \
	src/rt/typeinfo/ti_cdouble.d \
	src/rt/typeinfo/ti_cfloat.d \
	src/rt/typeinfo/ti_char.d \
	src/rt/typeinfo/ti_creal.d \
	src/rt/typeinfo/ti_dchar.d \
	src/rt/typeinfo/ti_delegate.d \
	src/rt/typeinfo/ti_double.d \
	src/rt/typeinfo/ti_float.d \
	src/rt/typeinfo/ti_idouble.d \
	src/rt/typeinfo/ti_ifloat.d \
	src/rt/typeinfo/ti_int.d \
	src/rt/typeinfo/ti_ireal.d \
	src/rt/typeinfo/ti_long.d \
	src/rt/typeinfo/ti_ptr.d \
	src/rt/typeinfo/ti_real.d \
	src/rt/typeinfo/ti_short.d \
	src/rt/typeinfo/ti_ubyte.d \
	src/rt/typeinfo/ti_uint.d \
	src/rt/typeinfo/ti_ulong.d \
	src/rt/typeinfo/ti_ushort.d \
	src/rt/typeinfo/ti_void.d \
	src/rt/typeinfo/ti_wchar.d \
	\
	$(IMPDIR)/std/intrinsic.di \
	$(IMPDIR)/core/stdc/config.d \
	$(IMPDIR)/core/stdc/ctype.d \
	$(IMPDIR)/core/stdc/errno.d \
	$(IMPDIR)/core/stdc/math.d \
	$(IMPDIR)/core/stdc/signal.d \
	$(IMPDIR)/core/stdc/stdarg.d \
	$(IMPDIR)/core/stdc/stdio.d \
	$(IMPDIR)/core/stdc/stdlib.d \
	$(IMPDIR)/core/stdc/stdint.d \
	$(IMPDIR)/core/stdc/stddef.d \
	$(IMPDIR)/core/stdc/string.d \
	$(IMPDIR)/core/stdc/time.d \
	$(IMPDIR)/core/stdc/wchar_.d \
	$(IMPDIR)/core/sys/posix/sys/select.d \
	$(IMPDIR)/core/sys/posix/sys/socket.d \
	$(IMPDIR)/core/sys/posix/sys/stat.d \
	$(IMPDIR)/core/sys/posix/sys/wait.d \
	$(IMPDIR)/core/sys/posix/netinet/in_.d

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for Linux

OBJS= $(OBJDIR)/errno_c.o $(OBJDIR)/threadasm.o $(OBJDIR)/complex.o	\
$(OBJDIR)/critical.o $(OBJDIR)/memory_osx.o $(OBJDIR)/monitor.o

DOCS=\
	$(DOCDIR)/core/bitop.html \
	$(DOCDIR)/core/cpuid.html \
	$(DOCDIR)/core/exception.html \
	$(DOCDIR)/core/memory.html \
	$(DOCDIR)/core/runtime.html \
	$(DOCDIR)/core/thread.html \
	$(DOCDIR)/core/vararg.html \
	\
	$(DOCDIR)/core/sync/barrier.html \
	$(DOCDIR)/core/sync/condition.html \
	$(DOCDIR)/core/sync/config.html \
	$(DOCDIR)/core/sync/exception.html \
	$(DOCDIR)/core/sync/mutex.html \
	$(DOCDIR)/core/sync/rwmutex.html \
	$(DOCDIR)/core/sync/semaphore.html

IMPORTS=\
	$(IMPDIR)/core/bitop.di \
	$(IMPDIR)/core/cpuid.di \
	$(IMPDIR)/core/exception.di \
	$(IMPDIR)/core/memory.di \
	$(IMPDIR)/core/runtime.di \
	$(IMPDIR)/core/thread.di \
	$(IMPDIR)/core/vararg.di \
	\
	$(IMPDIR)/core/sync/exception.di \
	$(IMPDIR)/core/sync/mutex.di \
	$(IMPDIR)/core/sync/config.di \
	$(IMPDIR)/core/sync/condition.di \
	$(IMPDIR)/core/sync/barrier.di \
	$(IMPDIR)/core/sync/rwmutex.di \
	$(IMPDIR)/core/sync/semaphore.di

######################## Doc .html file generation ##############################

html: $(DOCS)

$(DOCDIR)/core/%.html : src/core/%.d
	$(DMD) -c -d -o- -Iimport -Isrc -Df$@ $<

######################## Header .di file generation ##############################

import: $(IMPORTS)

$(IMPDIR)/core/%.di : src/core/%.d
	$(DMD) -c -d -o- -Iimport -Isrc -Hf$@ $<

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
	$(DMD) -lib -of$(DRUNTIME) $(DFLAGS) $(SRCS) $(OBJS)

unittest : $(SRCS) $(DRUNTIME) src/unittest.d
	$(DMD) $(UDFLAGS) -unittest src/unittest.d $(SRCS) $(DRUNTIME)

zip: druntime.zip

druntime.zip:
	rm $@
	zip -u $@ $(MANIFEST) $(DOCS) $(IMPORTS) minit.o

install: druntime.zip
	unzip -o druntime.zip -d /dmd2/src/druntime

clean:
	rm -f $(DOCS) $(IMPORTS) $(DRUNTIME) $(OBJS)
