
DMD=dmd

DOCDIR=doc
IMPDIR=import

DFLAGS=-O -release -nofloat -w -d
UDFLAGS=-O -release -nofloat -w -d

CFLAGS=-m32 -O

DRUNTIME=libdruntime.a

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
	src/build-dmd.bat \
	src/build-dmd.sh \
	src/common/core/bitop.d \
	src/common/core/exception.d \
	src/common/core/memory.d \
	src/common/core/runtime.d \
	src/common/core/stdc/errno.c \
	src/common/core/sync/barrier.d \
	src/common/core/sync/condition.d \
	src/common/core/sync/config.d \
	src/common/core/sync/exception.d \
	src/common/core/sync/mutex.d \
	src/common/core/sync/rwmutex.d \
	src/common/core/sync/semaphore.d \
	src/common/core/thread.d \
	src/common/core/threadasm.S \
	src/common/core/vararg.d \
	src/common/posix.mak \
	src/common/win32.mak \
	src/compiler/dmd/complex.c \
	src/compiler/dmd/critical.c \
	src/compiler/dmd/deh.c \
	src/compiler/dmd/mars.h \
	src/compiler/dmd/memory_osx.c \
	src/compiler/dmd/minit.asm \
	src/compiler/dmd/monitor.c \
	src/compiler/dmd/object_.d \
	src/compiler/dmd/posix.mak \
	src/compiler/dmd/rt/aApply.d \
	src/compiler/dmd/rt/aApplyR.d \
	src/compiler/dmd/rt/aaA.d \
	src/compiler/dmd/rt/adi.d \
	src/compiler/dmd/rt/alloca.d \
	src/compiler/dmd/rt/arrayassign.d \
	src/compiler/dmd/rt/arraybyte.d \
	src/compiler/dmd/rt/arraycast.d \
	src/compiler/dmd/rt/arraycat.d \
	src/compiler/dmd/rt/arraydouble.d \
	src/compiler/dmd/rt/arrayfloat.d \
	src/compiler/dmd/rt/arrayint.d \
	src/compiler/dmd/rt/arrayreal.d \
	src/compiler/dmd/rt/arrayshort.d \
	src/compiler/dmd/rt/cast_.d \
	src/compiler/dmd/rt/cmath2.d \
	src/compiler/dmd/rt/compiler.d \
	src/compiler/dmd/rt/cover.d \
	src/compiler/dmd/rt/deh2.d \
	src/compiler/dmd/rt/dmain2.d \
	src/compiler/dmd/rt/invariant.d \
	src/compiler/dmd/rt/invariant_.d \
	src/compiler/dmd/rt/lifetime.d \
	src/compiler/dmd/rt/llmath.d \
	src/compiler/dmd/rt/memory.d \
	src/compiler/dmd/rt/memset.d \
	src/compiler/dmd/rt/obj.d \
	src/compiler/dmd/rt/qsort.d \
	src/compiler/dmd/rt/qsort2.d \
	src/compiler/dmd/rt/switch_.d \
	src/compiler/dmd/rt/trace.d \
	src/compiler/dmd/rt/typeinfo/ti_AC.d \
	src/compiler/dmd/rt/typeinfo/ti_Acdouble.d \
	src/compiler/dmd/rt/typeinfo/ti_Acfloat.d \
	src/compiler/dmd/rt/typeinfo/ti_Acreal.d \
	src/compiler/dmd/rt/typeinfo/ti_Adouble.d \
	src/compiler/dmd/rt/typeinfo/ti_Afloat.d \
	src/compiler/dmd/rt/typeinfo/ti_Ag.d \
	src/compiler/dmd/rt/typeinfo/ti_Aint.d \
	src/compiler/dmd/rt/typeinfo/ti_Along.d \
	src/compiler/dmd/rt/typeinfo/ti_Areal.d \
	src/compiler/dmd/rt/typeinfo/ti_Ashort.d \
	src/compiler/dmd/rt/typeinfo/ti_C.d \
	src/compiler/dmd/rt/typeinfo/ti_byte.d \
	src/compiler/dmd/rt/typeinfo/ti_cdouble.d \
	src/compiler/dmd/rt/typeinfo/ti_cfloat.d \
	src/compiler/dmd/rt/typeinfo/ti_char.d \
	src/compiler/dmd/rt/typeinfo/ti_creal.d \
	src/compiler/dmd/rt/typeinfo/ti_dchar.d \
	src/compiler/dmd/rt/typeinfo/ti_delegate.d \
	src/compiler/dmd/rt/typeinfo/ti_double.d \
	src/compiler/dmd/rt/typeinfo/ti_float.d \
	src/compiler/dmd/rt/typeinfo/ti_idouble.d \
	src/compiler/dmd/rt/typeinfo/ti_ifloat.d \
	src/compiler/dmd/rt/typeinfo/ti_int.d \
	src/compiler/dmd/rt/typeinfo/ti_ireal.d \
	src/compiler/dmd/rt/typeinfo/ti_long.d \
	src/compiler/dmd/rt/typeinfo/ti_ptr.d \
	src/compiler/dmd/rt/typeinfo/ti_real.d \
	src/compiler/dmd/rt/typeinfo/ti_short.d \
	src/compiler/dmd/rt/typeinfo/ti_ubyte.d \
	src/compiler/dmd/rt/typeinfo/ti_uint.d \
	src/compiler/dmd/rt/typeinfo/ti_ulong.d \
	src/compiler/dmd/rt/typeinfo/ti_ushort.d \
	src/compiler/dmd/rt/typeinfo/ti_void.d \
	src/compiler/dmd/rt/typeinfo/ti_wchar.d \
	src/compiler/dmd/rt/util/console.d \
	src/compiler/dmd/rt/util/cpuid.d \
	src/compiler/dmd/rt/util/ctype.d \
	src/compiler/dmd/rt/util/hash.d \
	src/compiler/dmd/rt/util/string.d \
	src/compiler/dmd/rt/util/utf.d \
	src/compiler/dmd/tls.S \
	src/compiler/dmd/win32.mak \
	src/dmd-posix.mak \
	src/dmd-win32.mak \
	src/dmd.conf \
	src/gc/basic/gc.d \
	src/gc/basic/gcalloc.d \
	src/gc/basic/gcbits.d \
	src/gc/basic/gcstats.d \
	src/gc/basic/gcx.d \
	src/gc/basic/posix.mak \
	src/gc/basic/win32.mak \
	src/gc/stub/gc.d \
	src/gc/stub/posix.mak \
	src/gc/stub/win32.mak \
	src/sc.ini \
	src/test-dmd.bat \
	src/test-dmd.sh \
	src/unittest.d

SRCS= \
	src/common/core/bitop.d \
	src/common/core/exception.d \
	src/common/core/memory.d \
	src/common/core/runtime.d \
	src/common/core/thread.d \
	src/common/core/vararg.d \
	\
	src/common/core/sync/condition.d \
	src/common/core/sync/barrier.d \
	src/common/core/sync/config.d \
	src/common/core/sync/exception.d \
	src/common/core/sync/mutex.d \
	src/common/core/sync/rwmutex.d \
	src/common/core/sync/semaphore.d \
	\
	src/gc/basic/gc.d \
	src/gc/basic/gcalloc.d \
	src/gc/basic/gcbits.d \
	src/gc/basic/gcstats.d \
	src/gc/basic/gcx.d \
	\
	src/compiler/dmd/object_.d \
	\
	src/compiler/dmd/rt/aaA.d \
	src/compiler/dmd/rt/aApply.d \
	src/compiler/dmd/rt/aApplyR.d \
	src/compiler/dmd/rt/adi.d \
	src/compiler/dmd/rt/alloca.d \
	src/compiler/dmd/rt/arrayassign.d \
	src/compiler/dmd/rt/arraybyte.d \
	src/compiler/dmd/rt/arraycast.d \
	src/compiler/dmd/rt/arraycat.d \
	src/compiler/dmd/rt/arraydouble.d \
	src/compiler/dmd/rt/arrayfloat.d \
	src/compiler/dmd/rt/arrayint.d \
	src/compiler/dmd/rt/arrayreal.d \
	src/compiler/dmd/rt/arrayshort.d \
	src/compiler/dmd/rt/cast_.d \
	src/compiler/dmd/rt/cmath2.d \
	src/compiler/dmd/rt/cover.d \
	src/compiler/dmd/rt/deh2.d \
	src/compiler/dmd/rt/dmain2.d \
	src/compiler/dmd/rt/invariant.d \
	src/compiler/dmd/rt/invariant_.d \
	src/compiler/dmd/rt/lifetime.d \
	src/compiler/dmd/rt/llmath.d \
	src/compiler/dmd/rt/memory.d \
	src/compiler/dmd/rt/memset.d \
	src/compiler/dmd/rt/obj.d \
	src/compiler/dmd/rt/qsort.d \
	src/compiler/dmd/rt/switch_.d \
	src/compiler/dmd/rt/trace.d \
	\
	src/compiler/dmd/rt/util/console.d \
	src/compiler/dmd/rt/util/cpuid.d \
	src/compiler/dmd/rt/util/ctype.d \
	src/compiler/dmd/rt/util/hash.d \
	src/compiler/dmd/rt/util/string.d \
	src/compiler/dmd/rt/util/utf.d \
	\
	src/compiler/dmd/rt/typeinfo/ti_AC.d \
	src/compiler/dmd/rt/typeinfo/ti_Acdouble.d \
	src/compiler/dmd/rt/typeinfo/ti_Acfloat.d \
	src/compiler/dmd/rt/typeinfo/ti_Acreal.d \
	src/compiler/dmd/rt/typeinfo/ti_Adouble.d \
	src/compiler/dmd/rt/typeinfo/ti_Afloat.d \
	src/compiler/dmd/rt/typeinfo/ti_Ag.d \
	src/compiler/dmd/rt/typeinfo/ti_Aint.d \
	src/compiler/dmd/rt/typeinfo/ti_Along.d \
	src/compiler/dmd/rt/typeinfo/ti_Areal.d \
	src/compiler/dmd/rt/typeinfo/ti_Ashort.d \
	src/compiler/dmd/rt/typeinfo/ti_byte.d \
	src/compiler/dmd/rt/typeinfo/ti_C.d \
	src/compiler/dmd/rt/typeinfo/ti_cdouble.d \
	src/compiler/dmd/rt/typeinfo/ti_cfloat.d \
	src/compiler/dmd/rt/typeinfo/ti_char.d \
	src/compiler/dmd/rt/typeinfo/ti_creal.d \
	src/compiler/dmd/rt/typeinfo/ti_dchar.d \
	src/compiler/dmd/rt/typeinfo/ti_delegate.d \
	src/compiler/dmd/rt/typeinfo/ti_double.d \
	src/compiler/dmd/rt/typeinfo/ti_float.d \
	src/compiler/dmd/rt/typeinfo/ti_idouble.d \
	src/compiler/dmd/rt/typeinfo/ti_ifloat.d \
	src/compiler/dmd/rt/typeinfo/ti_int.d \
	src/compiler/dmd/rt/typeinfo/ti_ireal.d \
	src/compiler/dmd/rt/typeinfo/ti_long.d \
	src/compiler/dmd/rt/typeinfo/ti_ptr.d \
	src/compiler/dmd/rt/typeinfo/ti_real.d \
	src/compiler/dmd/rt/typeinfo/ti_short.d \
	src/compiler/dmd/rt/typeinfo/ti_ubyte.d \
	src/compiler/dmd/rt/typeinfo/ti_uint.d \
	src/compiler/dmd/rt/typeinfo/ti_ulong.d \
	src/compiler/dmd/rt/typeinfo/ti_ushort.d \
	src/compiler/dmd/rt/typeinfo/ti_void.d \
	src/compiler/dmd/rt/typeinfo/ti_wchar.d \
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
	$(IMPDIR)/core/sys/posix/sys/select.d

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for Linux

OBJS= errno_c.o threadasm.o complex.o critical.o memory_osx.o monitor.o

DOCS=\
	$(DOCDIR)/core/bitop.html \
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
	$(IMPDIR)/core/sync/exception.di \
	$(IMPDIR)/core/exception.di \
	$(IMPDIR)/core/memory.di \
	$(IMPDIR)/core/runtime.di \
	$(IMPDIR)/core/thread.di \
	$(IMPDIR)/core/vararg.di \
	\
	$(IMPDIR)/core/sync/mutex.di \
	$(IMPDIR)/core/sync/config.di \
	$(IMPDIR)/core/sync/condition.di \
	$(IMPDIR)/core/sync/barrier.di \
	$(IMPDIR)/core/sync/rwmutex.di \
	$(IMPDIR)/core/sync/semaphore.di

# bitop.di is already published

######################## Doc .html file generation ##############################

doc: $(DOCS)

$(DOCDIR)/core/bitop.html : src/common/core/bitop.d
	$(DMD) -c -d -o- -Df$@ $<

$(DOCDIR)/core/exception.html : src/common/core/exception.d
	$(DMD) -c -d -o- -Df$@ $<

$(DOCDIR)/core/memory.html : src/common/core/memory.d
	$(DMD) -c -d -o- -Df$@ $<

$(DOCDIR)/core/runtime.html : src/common/core/runtime.d
	$(DMD) -c -d -o- -Df$@ $<

$(DOCDIR)/core/thread.html : src/common/core/thread.d
	$(DMD) -c -d -o- -Df$@ $<

$(DOCDIR)/core/vararg.html : src/common/core/vararg.d
	$(DMD) -c -d -o- -Df$@ $<

$(DOCDIR)/core/sync/barrier.html : src/common/core/sync/barrier.d
	$(DMD) -c -d -o- -Df$@ $<

$(DOCDIR)/core/sync/condition.html : src/common/core/sync/condition.d
	$(DMD) -c -d -o- -Df$@ $<

$(DOCDIR)/core/sync/config.html : src/common/core/sync/config.d
	$(DMD) -c -d -o- -Df$@ $<

$(DOCDIR)/core/sync/exception.html : src/common/core/sync/exception.d
	$(DMD) -c -d -o- -Df$@ $<

$(DOCDIR)/core/sync/mutex.html : src/common/core/sync/mutex.d
	$(DMD) -c -d -o- -Df$@ $<

$(DOCDIR)/core/sync/rwmutex.html : src/common/core/sync/rwmutex.d
	$(DMD) -c -d -o- -Df$@ $<

$(DOCDIR)/core/sync/semaphore.html : src/common/core/sync/semaphore.d
	$(DMD) -c -d -o- -Df$@ $<

######################## Header .di file generation ##############################

import: $(IMPORTS)

$(IMPDIR)/core/exception.di : src/common/core/exception.d
	$(DMD) -c -d -o- -Hf$@ $<

$(IMPDIR)/core/memory.di : src/common/core/memory.d
	$(DMD) -c -d -o- -Hf$@ $<

$(IMPDIR)/core/runtime.di : src/common/core/runtime.d
	$(DMD) -c -d -o- -Hf$@ $<

$(IMPDIR)/core/thread.di : src/common/core/thread.d
	$(DMD) -c -d -o- -Hf$@ $<

$(IMPDIR)/core/vararg.di : src/common/core/vararg.d
	$(DMD) -c -d -o- -Hf$@ $<

$(IMPDIR)/core/sync/barrier.di : src/common/core/sync/barrier.d
	$(DMD) -c -d -o- -Hf$@ $<

$(IMPDIR)/core/sync/condition.di : src/common/core/sync/condition.d
	$(DMD) -c -d -o- -Hf$@ $<

$(IMPDIR)/core/sync/config.di : src/common/core/sync/config.d
	$(DMD) -c -d -o- -Hf$@ $<

$(IMPDIR)/core/sync/exception.di : src/common/core/sync/exception.d
	$(DMD) -c -d -o- -Hf$@ $<

$(IMPDIR)/core/sync/mutex.di : src/common/core/sync/mutex.d
	$(DMD) -c -d -o- -Hf$@ $<

$(IMPDIR)/core/sync/rwmutex.di : src/common/core/sync/rwmutex.d
	$(DMD) -c -d -o- -Hf$@ $<

$(IMPDIR)/core/sync/semaphore.di : src/common/core/sync/semaphore.d
	$(DMD) -c -d -o- -Hf$@ $<

################### C/ASM Targets ############################

complex.o : src/compiler/dmd/complex.c
	$(CC) -c $(CFLAGS) $<

critical.o : src/compiler/dmd/critical.c
	$(CC) -c $(CFLAGS) $<

memory_osx.o : src/compiler/dmd/memory_osx.c
	$(CC) -c $(CFLAGS) $<

monitor.o : src/compiler/dmd/monitor.c
	$(CC) -c $(CFLAGS) $<

errno_c.o : src/common/core/stdc/errno.c
	$(CC) -c $(CFLAGS) src/common/core/stdc/errno.c -oerrno_c.o

threadasm.o : src/common/core/threadasm.S
	$(CC) -c $(CFLAGS) $<

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) win32.mak
	$(DMD) -lib -of$(DRUNTIME) $(DFLAGS) $(SRCS) $(OBJS)

unittest : $(SRCS) $(DRUNTIME)
	$(DMD) $(UDFLAGS) -L/co -unittest src/unittest.d $(SRCS) $(DRUNTIME)

druntime.zip : zip

zip:
	rm druntime.zip
	zip -u druntime $(MANIFEST) $(DOCS) $(IMPORTS) minit.o

install: druntime.zip
	unzip -o druntime.zip -d /dmd2/src/druntime

clean:
	rm -f $(DOCS) $(IMPORTS) $(DRUNTIME) $(OBJS)
