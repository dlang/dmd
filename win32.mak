
DMD=dmd

CC=dmc

DOCDIR=doc
IMPDIR=import

DFLAGS=-O -release -inline -w -Isrc -Iimport -property
UDFLAGS=-O -release -w -Isrc -Iimport -property
DDOCFLAGS=-c -w -o- -Isrc -Iimport

CFLAGS=

DRUNTIME_BASE=druntime
DRUNTIME=lib\$(DRUNTIME_BASE).lib
GCSTUB=lib\gcstub.obj

DOCFMT=-version=CoreDdoc

target : import copydir copy $(DRUNTIME) doc $(GCSTUB)

MANIFEST= \
	LICENSE \
	README \
	posix.mak \
	win32.mak \
	\
	src\object_.d \
	src\object.di \
	\
	src\core\atomic.d \
	src\core\bitop.d \
	src\core\cpuid.d \
	src\core\demangle.d \
	src\core\exception.d \
	src\core\math.d \
	src\core\memory.d \
	src\core\runtime.d \
	src\core\simd.d \
	src\core\thread.d \
	src\core\thread.di \
	src\core\time.d \
	src\core\vararg.d \
	\
	src\core\stdc\complex.d \
	src\core\stdc\config.d \
	src\core\stdc\ctype.d \
	src\core\stdc\errno.c \
	src\core\stdc\errno.d \
	src\core\stdc\fenv.d \
	src\core\stdc\float_.d \
	src\core\stdc\inttypes.d \
	src\core\stdc\limits.d \
	src\core\stdc\locale.d \
	src\core\stdc\math.d \
	src\core\stdc\signal.d \
	src\core\stdc\stdarg.d \
	src\core\stdc\stddef.d \
	src\core\stdc\stdint.d \
	src\core\stdc\stdio.d \
	src\core\stdc\stdlib.d \
	src\core\stdc\string.d \
	src\core\stdc\tgmath.d \
	src\core\stdc\time.d \
	src\core\stdc\wchar_.d \
	src\core\stdc\wctype.d \
	\
	src\core\sync\barrier.d \
	src\core\sync\condition.d \
	src\core\sync\config.d \
	src\core\sync\exception.d \
	src\core\sync\mutex.d \
	src\core\sync\rwmutex.d \
	src\core\sync\semaphore.d \
	\
	src\core\sys\freebsd\dlfcn.d \
	src\core\sys\freebsd\execinfo.d \
	src\core\sys\freebsd\sys\event.d \
	\
	src\core\sys\linux\execinfo.d \
	src\core\sys\linux\sys\xattr.d \
	\
	src\core\sys\osx\execinfo.d \
	src\core\sys\osx\pthread.d \
	src\core\sys\osx\mach\dyld.d \
	src\core\sys\osx\mach\getsect.d \
	src\core\sys\osx\mach\kern_return.d \
	src\core\sys\osx\mach\loader.d \
	src\core\sys\osx\mach\port.d \
	src\core\sys\osx\mach\semaphore.d \
	src\core\sys\osx\mach\thread_act.d \
	\
	src\core\sys\posix\config.d \
	src\core\sys\posix\dirent.d \
	src\core\sys\posix\dlfcn.d \
	src\core\sys\posix\fcntl.d \
	src\core\sys\posix\inttypes.d \
	src\core\sys\posix\net\if_.d \
	src\core\sys\posix\netdb.d \
	src\core\sys\posix\poll.d \
	src\core\sys\posix\pthread.d \
	src\core\sys\posix\pwd.d \
	src\core\sys\posix\sched.d \
	src\core\sys\posix\semaphore.d \
	src\core\sys\posix\setjmp.d \
	src\core\sys\posix\signal.d \
	src\core\sys\posix\stdio.d \
	src\core\sys\posix\stdlib.d \
	src\core\sys\posix\termios.d \
	src\core\sys\posix\time.d \
	src\core\sys\posix\ucontext.d \
	src\core\sys\posix\unistd.d \
	src\core\sys\posix\utime.d \
	\
	src\core\sys\posix\arpa\inet.d \
	\
	src\core\sys\posix\netinet\in_.d \
	src\core\sys\posix\netinet\tcp.d \
	\
	src\core\sys\posix\sys\ipc.d \
	src\core\sys\posix\sys\mman.d \
	src\core\sys\posix\sys\select.d \
	src\core\sys\posix\sys\shm.d \
	src\core\sys\posix\sys\socket.d \
	src\core\sys\posix\sys\stat.d \
	src\core\sys\posix\sys\time.d \
	src\core\sys\posix\sys\types.d \
	src\core\sys\posix\sys\uio.d \
	src\core\sys\posix\sys\un.d \
	src\core\sys\posix\sys\wait.d \
	src\core\sys\posix\sys\utsname.d \
	\
	src\core\sys\windows\dbghelp.d \
	src\core\sys\windows\dll.d \
	src\core\sys\windows\stacktrace.d \
	src\core\sys\windows\threadaux.d \
	src\core\sys\windows\windows.d \
	\
	src\gc\gc.d \
	src\gc\gcalloc.d \
	src\gc\gcbits.d \
	src\gc\gcstats.d \
	src\gc\gcx.d \
	\
	src\gcstub\gc.d \
	\
	src\rt\aApply.d \
	src\rt\aApplyR.d \
	src\rt\aaA.d \
	src\rt\adi.d \
	src\rt\alloca.d \
	src\rt\arrayassign.d \
	src\rt\arraybyte.d \
	src\rt\arraycast.d \
	src\rt\arraycat.d \
	src\rt\arraydouble.d \
	src\rt\arrayfloat.d \
	src\rt\arrayint.d \
	src\rt\arrayreal.d \
	src\rt\arrayshort.d \
	src\rt\cast_.d \
	src\rt\cmath2.d \
	src\rt\complex.c \
	src\rt\cover.d \
	src\rt\critical.c \
	src\rt\critical_.d \
	src\rt\deh.d \
	src\rt\deh2.d \
	src\rt\dmain2.d \
	src\rt\dylib_fixes.c \
	src\rt\image.d \
	src\rt\invariant.d \
	src\rt\invariant_.d \
	src\rt\lifetime.d \
	src\rt\llmath.d \
	src\rt\mars.h \
	src\rt\memory.d \
	src\rt\memory_osx.d \
	src\rt\memset.d \
	src\rt\minfo.d \
	src\rt\minit.asm \
	src\rt\monitor.c \
	src\rt\monitor_.d \
	src\rt\obj.d \
	src\rt\qsort.d \
	src\rt\qsort2.d \
	src\rt\switch_.d \
	src\rt\tls.S \
	src\rt\tlsgc.d \
	src\rt\trace.d \
	\
	src\rt\typeinfo\ti_AC.d \
	src\rt\typeinfo\ti_Acdouble.d \
	src\rt\typeinfo\ti_Acfloat.d \
	src\rt\typeinfo\ti_Acreal.d \
	src\rt\typeinfo\ti_Adouble.d \
	src\rt\typeinfo\ti_Afloat.d \
	src\rt\typeinfo\ti_Ag.d \
	src\rt\typeinfo\ti_Aint.d \
	src\rt\typeinfo\ti_Along.d \
	src\rt\typeinfo\ti_Areal.d \
	src\rt\typeinfo\ti_Ashort.d \
	src\rt\typeinfo\ti_C.d \
	src\rt\typeinfo\ti_byte.d \
	src\rt\typeinfo\ti_cdouble.d \
	src\rt\typeinfo\ti_cfloat.d \
	src\rt\typeinfo\ti_char.d \
	src\rt\typeinfo\ti_creal.d \
	src\rt\typeinfo\ti_dchar.d \
	src\rt\typeinfo\ti_delegate.d \
	src\rt\typeinfo\ti_double.d \
	src\rt\typeinfo\ti_float.d \
	src\rt\typeinfo\ti_idouble.d \
	src\rt\typeinfo\ti_ifloat.d \
	src\rt\typeinfo\ti_int.d \
	src\rt\typeinfo\ti_ireal.d \
	src\rt\typeinfo\ti_long.d \
	src\rt\typeinfo\ti_ptr.d \
	src\rt\typeinfo\ti_real.d \
	src\rt\typeinfo\ti_short.d \
	src\rt\typeinfo\ti_ubyte.d \
	src\rt\typeinfo\ti_uint.d \
	src\rt\typeinfo\ti_ulong.d \
	src\rt\typeinfo\ti_ushort.d \
	src\rt\typeinfo\ti_void.d \
	src\rt\typeinfo\ti_wchar.d \
	\
	src\rt\util\console.d \
	src\rt\util\hash.d \
	src\rt\util\string.d \
	src\rt\util\utf.d

SRCS= \
	src\object_.d \
	\
	src\core\atomic.d \
	src\core\bitop.d \
	src\core\cpuid.d \
	src\core\demangle.d \
	src\core\exception.d \
	src\core\math.d \
	src\core\memory.d \
	src\core\runtime.d \
	src\core\simd.d \
	src\core\thread.d \
	src\core\time.d \
	src\core\vararg.d \
	\
	src\core\stdc\config.d \
	src\core\stdc\ctype.d \
	src\core\stdc\errno.d \
	src\core\stdc\math.d \
	src\core\stdc\signal.d \
	src\core\stdc\stdarg.d \
	src\core\stdc\stdio.d \
	src\core\stdc\stdlib.d \
	src\core\stdc\stdint.d \
	src\core\stdc\stddef.d \
	src\core\stdc\string.d \
	src\core\stdc\time.d \
	src\core\stdc\wchar_.d \
	\
	src\core\sys\windows\dbghelp.d \
	src\core\sys\windows\dll.d \
	src\core\sys\windows\stacktrace.d \
	src\core\sys\windows\threadaux.d \
	src\core\sys\windows\windows.d \
	\
	src\core\sync\barrier.d \
	src\core\sync\condition.d \
	src\core\sync\config.d \
	src\core\sync\exception.d \
	src\core\sync\mutex.d \
	src\core\sync\rwmutex.d \
	src\core\sync\semaphore.d \
	\
	src\gc\gc.d \
	src\gc\gcalloc.d \
	src\gc\gcbits.d \
	src\gc\gcstats.d \
	src\gc\gcx.d \
	\
	src\rt\aaA.d \
	src\rt\aApply.d \
	src\rt\aApplyR.d \
	src\rt\adi.d \
	src\rt\arrayassign.d \
	src\rt\arraybyte.d \
	src\rt\arraycast.d \
	src\rt\arraycat.d \
	src\rt\arraydouble.d \
	src\rt\arrayfloat.d \
	src\rt\arrayint.d \
	src\rt\arrayreal.d \
	src\rt\arrayshort.d \
	src\rt\cast_.d \
	src\rt\cover.d \
	src\rt\deh.d \
	src\rt\dmain2.d \
	src\rt\invariant.d \
	src\rt\invariant_.d \
	src\rt\lifetime.d \
	src\rt\llmath.d \
	src\rt\memory.d \
	src\rt\memset.d \
	src\rt\minfo.d \
	src\rt\obj.d \
	src\rt\qsort.d \
	src\rt\switch_.d \
	src\rt\tlsgc.d \
	src\rt\trace.d \
	\
	src\rt\util\console.d \
	src\rt\util\hash.d \
	src\rt\util\string.d \
	src\rt\util\utf.d \
	\
	src\rt\typeinfo\ti_AC.d \
	src\rt\typeinfo\ti_Acdouble.d \
	src\rt\typeinfo\ti_Acfloat.d \
	src\rt\typeinfo\ti_Acreal.d \
	src\rt\typeinfo\ti_Adouble.d \
	src\rt\typeinfo\ti_Afloat.d \
	src\rt\typeinfo\ti_Ag.d \
	src\rt\typeinfo\ti_Aint.d \
	src\rt\typeinfo\ti_Along.d \
	src\rt\typeinfo\ti_Areal.d \
	src\rt\typeinfo\ti_Ashort.d \
	src\rt\typeinfo\ti_byte.d \
	src\rt\typeinfo\ti_C.d \
	src\rt\typeinfo\ti_cdouble.d \
	src\rt\typeinfo\ti_cfloat.d \
	src\rt\typeinfo\ti_char.d \
	src\rt\typeinfo\ti_creal.d \
	src\rt\typeinfo\ti_dchar.d \
	src\rt\typeinfo\ti_delegate.d \
	src\rt\typeinfo\ti_double.d \
	src\rt\typeinfo\ti_float.d \
	src\rt\typeinfo\ti_idouble.d \
	src\rt\typeinfo\ti_ifloat.d \
	src\rt\typeinfo\ti_int.d \
	src\rt\typeinfo\ti_ireal.d \
	src\rt\typeinfo\ti_long.d \
	src\rt\typeinfo\ti_ptr.d \
	src\rt\typeinfo\ti_real.d \
	src\rt\typeinfo\ti_short.d \
	src\rt\typeinfo\ti_ubyte.d \
	src\rt\typeinfo\ti_uint.d \
	src\rt\typeinfo\ti_ulong.d \
	src\rt\typeinfo\ti_ushort.d \
	src\rt\typeinfo\ti_void.d \
	src\rt\typeinfo\ti_wchar.d

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for Linux

OBJS= errno_c.obj complex.obj src\rt\minit.obj monitor.obj critical.obj
OBJS_TO_DELETE= errno_c.obj complex.obj monitor.obj critical.obj

DOCS=\
	$(DOCDIR)\object.html \
	$(DOCDIR)\core_atomic.html \
	$(DOCDIR)\core_bitop.html \
	$(DOCDIR)\core_cpuid.html \
	$(DOCDIR)\core_demangle.html \
	$(DOCDIR)\core_exception.html \
	$(DOCDIR)\core_math.html \
	$(DOCDIR)\core_memory.html \
	$(DOCDIR)\core_runtime.html \
	$(DOCDIR)\core_simd.html \
	$(DOCDIR)\core_thread.html \
	$(DOCDIR)\core_time.html \
	$(DOCDIR)\core_vararg.html \
	\
	$(DOCDIR)\core_sync_barrier.html \
	$(DOCDIR)\core_sync_condition.html \
	$(DOCDIR)\core_sync_config.html \
	$(DOCDIR)\core_sync_exception.html \
	$(DOCDIR)\core_sync_mutex.html \
	$(DOCDIR)\core_sync_rwmutex.html \
	$(DOCDIR)\core_sync_semaphore.html

IMPORTS=\
	$(IMPDIR)\object.di \
	$(IMPDIR)\core\sync\barrier.di \
	$(IMPDIR)\core\sync\condition.di \
	$(IMPDIR)\core\sync\config.di \
	$(IMPDIR)\core\sync\exception.di \
	$(IMPDIR)\core\sync\mutex.di \
	$(IMPDIR)\core\sync\rwmutex.di \
	$(IMPDIR)\core\sync\semaphore.di

COPY=\
	$(IMPDIR)\object.di \
	$(IMPDIR)\core\atomic.d \
	$(IMPDIR)\core\bitop.d \
	$(IMPDIR)\core\cpuid.d \
	$(IMPDIR)\core\demangle.d \
	$(IMPDIR)\core\exception.d \
	$(IMPDIR)\core\math.d \
	$(IMPDIR)\core\memory.d \
	$(IMPDIR)\core\runtime.d \
	$(IMPDIR)\core\simd.d \
	$(IMPDIR)\core\thread.di \
	$(IMPDIR)\core\time.d \
	$(IMPDIR)\core\vararg.d \
	\
	$(IMPDIR)\core\stdc\complex.d \
	$(IMPDIR)\core\stdc\config.d \
	$(IMPDIR)\core\stdc\ctype.d \
	$(IMPDIR)\core\stdc\errno.d \
	$(IMPDIR)\core\stdc\fenv.d \
	$(IMPDIR)\core\stdc\float_.d \
	$(IMPDIR)\core\stdc\inttypes.d \
	$(IMPDIR)\core\stdc\limits.d \
	$(IMPDIR)\core\stdc\locale.d \
	$(IMPDIR)\core\stdc\math.d \
	$(IMPDIR)\core\stdc\signal.d \
	$(IMPDIR)\core\stdc\stdarg.d \
	$(IMPDIR)\core\stdc\stddef.d \
	$(IMPDIR)\core\stdc\stdint.d \
	$(IMPDIR)\core\stdc\stdio.d \
	$(IMPDIR)\core\stdc\stdlib.d \
	$(IMPDIR)\core\stdc\string.d \
	$(IMPDIR)\core\stdc\tgmath.d \
	$(IMPDIR)\core\stdc\time.d \
	$(IMPDIR)\core\stdc\wchar_.d \
	$(IMPDIR)\core\stdc\wctype.d \
	\
	$(IMPDIR)\core\sys\freebsd\dlfcn.d \
	$(IMPDIR)\core\sys\freebsd\execinfo.d \
	$(IMPDIR)\core\sys\freebsd\sys\event.d \
	\
	$(IMPDIR)\core\sys\linux\execinfo.d \
	$(IMPDIR)\core\sys\linux\sys\xattr.d \
	\
	$(IMPDIR)\core\sys\osx\execinfo.d \
	$(IMPDIR)\core\sys\osx\pthread.d \
	$(IMPDIR)\core\sys\osx\mach\kern_return.d \
	$(IMPDIR)\core\sys\osx\mach\port.d \
	$(IMPDIR)\core\sys\osx\mach\semaphore.d \
	$(IMPDIR)\core\sys\osx\mach\thread_act.d \
	\
	$(IMPDIR)\core\sys\posix\arpa\inet.d \
	$(IMPDIR)\core\sys\posix\config.d \
	$(IMPDIR)\core\sys\posix\dirent.d \
	$(IMPDIR)\core\sys\posix\dlfcn.d \
	$(IMPDIR)\core\sys\posix\fcntl.d \
	$(IMPDIR)\core\sys\posix\inttypes.d \
	$(IMPDIR)\core\sys\posix\netdb.d \
	$(IMPDIR)\core\sys\posix\poll.d \
	$(IMPDIR)\core\sys\posix\pthread.d \
	$(IMPDIR)\core\sys\posix\pwd.d \
	$(IMPDIR)\core\sys\posix\sched.d \
	$(IMPDIR)\core\sys\posix\semaphore.d \
	$(IMPDIR)\core\sys\posix\setjmp.d \
	$(IMPDIR)\core\sys\posix\signal.d \
	$(IMPDIR)\core\sys\posix\stdio.d \
	$(IMPDIR)\core\sys\posix\stdlib.d \
	$(IMPDIR)\core\sys\posix\termios.d \
	$(IMPDIR)\core\sys\posix\time.d \
	$(IMPDIR)\core\sys\posix\ucontext.d \
	$(IMPDIR)\core\sys\posix\unistd.d \
	$(IMPDIR)\core\sys\posix\utime.d \
	\
	$(IMPDIR)\core\sys\posix\net\if_.d \
	\
	$(IMPDIR)\core\sys\posix\netinet\in_.d \
	$(IMPDIR)\core\sys\posix\netinet\tcp.d \
	\
	$(IMPDIR)\core\sys\posix\sys\ipc.d \
	$(IMPDIR)\core\sys\posix\sys\mman.d \
	$(IMPDIR)\core\sys\posix\sys\select.d \
	$(IMPDIR)\core\sys\posix\sys\shm.d \
	$(IMPDIR)\core\sys\posix\sys\socket.d \
	$(IMPDIR)\core\sys\posix\sys\stat.d \
	$(IMPDIR)\core\sys\posix\sys\time.d \
	$(IMPDIR)\core\sys\posix\sys\types.d \
	$(IMPDIR)\core\sys\posix\sys\uio.d \
	$(IMPDIR)\core\sys\posix\sys\un.d \
	$(IMPDIR)\core\sys\posix\sys\wait.d \
	$(IMPDIR)\core\sys\posix\sys\utsname.d \
	\
	$(IMPDIR)\core\sys\windows\dbghelp.d \
	$(IMPDIR)\core\sys\windows\dll.d \
	$(IMPDIR)\core\sys\windows\stacktrace.d \
	$(IMPDIR)\core\sys\windows\threadaux.d \
	$(IMPDIR)\core\sys\windows\windows.d

######################## Doc .html file generation ##############################

doc: $(DOCS)

$(DOCDIR)\object.html : src\object_.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_atomic.html : src\core\atomic.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_bitop.html : src\core\bitop.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_cpuid.html : src\core\cpuid.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_demangle.html : src\core\demangle.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_exception.html : src\core\exception.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_math.html : src\core\math.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_memory.html : src\core\memory.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_runtime.html : src\core\runtime.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_simd.html : src\core\simd.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_thread.html : $(IMPDIR)\core\thread.di
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_time.html : src\core\time.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_vararg.html : src\core\vararg.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_barrier.html : src\core\sync\barrier.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_condition.html : src\core\sync\condition.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_config.html : src\core\sync\config.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_exception.html : src\core\sync\exception.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_mutex.html : src\core\sync\mutex.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_rwmutex.html : src\core\sync\rwmutex.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_semaphore.html : src\core\sync\semaphore.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

######################## Header .di file generation ##############################

import: $(IMPORTS)

$(IMPDIR)\core\sync\barrier.di : src\core\sync\barrier.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\condition.di : src\core\sync\condition.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\config.di : src\core\sync\config.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\exception.di : src\core\sync\exception.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\mutex.di : src\core\sync\mutex.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\rwmutex.di : src\core\sync\rwmutex.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\semaphore.di : src\core\sync\semaphore.d
	$(DMD) -c -o- -Isrc -Iimport -Hf$@ $**

######################## Header .di file copy ##############################

copydir: $(IMPDIR)
	mkdir $(IMPDIR)\core\sys\windows
	mkdir $(IMPDIR)\core\sys\posix\arpa
	mkdir $(IMPDIR)\core\sys\posix\sys
	mkdir $(IMPDIR)\core\sys\posix\net
	mkdir $(IMPDIR)\core\sys\posix\netinet
	mkdir $(IMPDIR)\core\sys\osx\mach
	mkdir $(IMPDIR)\core\sys\freebsd\sys
	mkdir $(IMPDIR)\core\sys\linux\sys
	mkdir $(IMPDIR)\core\stdc

copy: $(COPY)

$(IMPDIR)\object.di : src\object.di
	copy $** $@

$(IMPDIR)\core\atomic.d : src\core\atomic.d
	copy $** $@

$(IMPDIR)\core\bitop.d : src\core\bitop.d
	copy $** $@

$(IMPDIR)\core\cpuid.d : src\core\cpuid.d
	copy $** $@

$(IMPDIR)\core\demangle.d : src\core\demangle.d
	copy $** $@

$(IMPDIR)\core\exception.d : src\core\exception.d
	copy $** $@

$(IMPDIR)\core\math.d : src\core\math.d
	copy $** $@

$(IMPDIR)\core\memory.d : src\core\memory.d
	copy $** $@

$(IMPDIR)\core\runtime.d : src\core\runtime.d
	copy $** $@

$(IMPDIR)\core\simd.d : src\core\simd.d
	copy $** $@

$(IMPDIR)\core\thread.di : src\core\thread.di
	copy $** $@

$(IMPDIR)\core\time.d : src\core\time.d
	copy $** $@

$(IMPDIR)\core\vararg.d : src\core\vararg.d
	copy $** $@

$(IMPDIR)\core\stdc\complex.d : src\core\stdc\complex.d
	copy $** $@

$(IMPDIR)\core\stdc\config.d : src\core\stdc\config.d
	copy $** $@

$(IMPDIR)\core\stdc\ctype.d : src\core\stdc\ctype.d
	copy $** $@

$(IMPDIR)\core\stdc\errno.d : src\core\stdc\errno.d
	copy $** $@

$(IMPDIR)\core\stdc\fenv.d : src\core\stdc\fenv.d
	copy $** $@

$(IMPDIR)\core\stdc\float_.d : src\core\stdc\float_.d
	copy $** $@

$(IMPDIR)\core\stdc\inttypes.d : src\core\stdc\inttypes.d
	copy $** $@

$(IMPDIR)\core\stdc\limits.d : src\core\stdc\limits.d
	copy $** $@

$(IMPDIR)\core\stdc\locale.d : src\core\stdc\locale.d
	copy $** $@

$(IMPDIR)\core\stdc\math.d : src\core\stdc\math.d
	copy $** $@

$(IMPDIR)\core\stdc\signal.d : src\core\stdc\signal.d
	copy $** $@

$(IMPDIR)\core\stdc\stdarg.d : src\core\stdc\stdarg.d
	copy $** $@

$(IMPDIR)\core\stdc\stddef.d : src\core\stdc\stddef.d
	copy $** $@

$(IMPDIR)\core\stdc\stdint.d : src\core\stdc\stdint.d
	copy $** $@

$(IMPDIR)\core\stdc\stdio.d : src\core\stdc\stdio.d
	copy $** $@

$(IMPDIR)\core\stdc\stdlib.d : src\core\stdc\stdlib.d
	copy $** $@

$(IMPDIR)\core\stdc\string.d : src\core\stdc\string.d
	copy $** $@

$(IMPDIR)\core\stdc\tgmath.d : src\core\stdc\tgmath.d
	copy $** $@

$(IMPDIR)\core\stdc\time.d : src\core\stdc\time.d
	copy $** $@

$(IMPDIR)\core\stdc\wchar_.d : src\core\stdc\wchar_.d
	copy $** $@

$(IMPDIR)\core\stdc\wctype.d : src\core\stdc\wctype.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\dlfcn.d : src\core\sys\freebsd\dlfcn.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\execinfo.d : src\core\sys\freebsd\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\event.d : src\core\sys\freebsd\sys\event.d
	copy $** $@

$(IMPDIR)\core\sys\linux\execinfo.d : src\core\sys\linux\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\xattr.d : src\core\sys\linux\sys\xattr.d
	copy $** $@

$(IMPDIR)\core\sys\osx\execinfo.d : src\core\sys\osx\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\osx\pthread.d : src\core\sys\osx\pthread.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\kern_return.d : src\core\sys\osx\mach\kern_return.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\port.d : src\core\sys\osx\mach\port.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\semaphore.d : src\core\sys\osx\mach\semaphore.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\thread_act.d : src\core\sys\osx\mach\thread_act.d
	copy $** $@

$(IMPDIR)\core\sys\posix\arpa\inet.d : src\core\sys\posix\arpa\inet.d
	copy $** $@

$(IMPDIR)\core\sys\posix\config.d : src\core\sys\posix\config.d
	copy $** $@

$(IMPDIR)\core\sys\posix\dirent.d : src\core\sys\posix\dirent.d
	copy $** $@

$(IMPDIR)\core\sys\posix\dlfcn.d : src\core\sys\posix\dlfcn.d
	copy $** $@

$(IMPDIR)\core\sys\posix\fcntl.d : src\core\sys\posix\fcntl.d
	copy $** $@

$(IMPDIR)\core\sys\posix\inttypes.d : src\core\sys\posix\inttypes.d
	copy $** $@

$(IMPDIR)\core\sys\posix\netdb.d : src\core\sys\posix\netdb.d
	copy $** $@

$(IMPDIR)\core\sys\posix\net\if_.d : src\core\sys\posix\net\if_.d
	copy $** $@

$(IMPDIR)\core\sys\posix\netinet\in_.d : src\core\sys\posix\netinet\in_.d
	copy $** $@

$(IMPDIR)\core\sys\posix\netinet\tcp.d : src\core\sys\posix\netinet\tcp.d
	copy $** $@

$(IMPDIR)\core\sys\posix\poll.d : src\core\sys\posix\poll.d
	copy $** $@

$(IMPDIR)\core\sys\posix\pthread.d : src\core\sys\posix\pthread.d
	copy $** $@

$(IMPDIR)\core\sys\posix\pwd.d : src\core\sys\posix\pwd.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sched.d : src\core\sys\posix\sched.d
	copy $** $@

$(IMPDIR)\core\sys\posix\semaphore.d : src\core\sys\posix\semaphore.d
	copy $** $@

$(IMPDIR)\core\sys\posix\setjmp.d : src\core\sys\posix\setjmp.d
	copy $** $@

$(IMPDIR)\core\sys\posix\signal.d : src\core\sys\posix\signal.d
	copy $** $@

$(IMPDIR)\core\sys\posix\stdio.d : src\core\sys\posix\stdio.d
	copy $** $@

$(IMPDIR)\core\sys\posix\stdlib.d : src\core\sys\posix\stdlib.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\ipc.d : src\core\sys\posix\sys\ipc.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\mman.d : src\core\sys\posix\sys\mman.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\select.d : src\core\sys\posix\sys\select.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\shm.d : src\core\sys\posix\sys\shm.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\socket.d : src\core\sys\posix\sys\socket.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\stat.d : src\core\sys\posix\sys\stat.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\time.d : src\core\sys\posix\sys\time.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\types.d : src\core\sys\posix\sys\types.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\uio.d : src\core\sys\posix\sys\uio.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\un.d : src\core\sys\posix\sys\un.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\wait.d : src\core\sys\posix\sys\wait.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\utsname.d : src\core\sys\posix\sys\utsname.d
	copy $** $@

$(IMPDIR)\core\sys\posix\termios.d : src\core\sys\posix\termios.d
	copy $** $@

$(IMPDIR)\core\sys\posix\time.d : src\core\sys\posix\time.d
	copy $** $@

$(IMPDIR)\core\sys\posix\ucontext.d : src\core\sys\posix\ucontext.d
	copy $** $@

$(IMPDIR)\core\sys\posix\unistd.d : src\core\sys\posix\unistd.d
	copy $** $@

$(IMPDIR)\core\sys\posix\utime.d : src\core\sys\posix\utime.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dbghelp.d : src\core\sys\windows\dbghelp.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dll.d : src\core\sys\windows\dll.d
	copy $** $@

$(IMPDIR)\core\sys\windows\stacktrace.d : src\core\sys\windows\stacktrace.d
	copy $** $@

$(IMPDIR)\core\sys\windows\threadaux.d : src\core\sys\windows\threadaux.d
	copy $** $@

$(IMPDIR)\core\sys\windows\windows.d : src\core\sys\windows\windows.d
	copy $** $@

################### C\ASM Targets ############################

errno_c.obj : src\core\stdc\errno.c
	$(CC) -c $(CFLAGS) src\core\stdc\errno.c -oerrno_c.obj

complex.obj : src\rt\complex.c
	$(CC) -c $(CFLAGS) src\rt\complex.c

src\rt\minit.obj : src\rt\minit.asm
	$(CC) -c $(CFLAGS) src\rt\minit.asm

critical.obj : src\rt\critical.c
	$(CC) -c $(CFLAGS) src\rt\critical.c

monitor.obj : src\rt\monitor.c
	$(CC) -c $(CFLAGS) src\rt\monitor.c

################### gcstub generation #########################

$(GCSTUB) : src\gcstub\gc.d win32.mak
	$(DMD) -c -of$(GCSTUB) src\gcstub\gc.d $(DFLAGS)

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) win32.mak
	$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

unittest : $(SRCS) $(DRUNTIME) src\unittest.d
	$(DMD) $(UDFLAGS) -L/co -version=druntime_unittest -unittest src\unittest.d $(SRCS) $(DRUNTIME) -debuglib=$(DRUNTIME) -defaultlib=$(DRUNTIME)

zip: druntime.zip

druntime.zip:
	del druntime.zip
	zip32 -ur druntime $(MANIFEST) $(DOCS) $(IMPDIR) src\rt\minit.obj

install: druntime.zip
	unzip -o druntime.zip -d \dmd2\src\druntime

clean:
	del $(DRUNTIME) $(OBJS_TO_DELETE) $(GCSTUB)
	rmdir /S /Q $(DOCDIR) $(IMPDIR)
