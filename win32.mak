
DMD=dmd

CC=dmc

DOCDIR=doc
IMPDIR=import

DFLAGS=-O -release -inline -nofloat -w -d -Isrc -Iimport
UDFLAGS=-O -release -nofloat -w -d -Isrc -Iimport

CFLAGS=

DRUNTIME_BASE=druntime
DRUNTIME=lib\$(DRUNTIME_BASE).lib
GCSTUB=lib\gcstub.obj

DOCFMT=

target : import $(DRUNTIME) doc $(GCSTUB)

MANIFEST= \
	LICENSE_1_0.txt \
	README.txt \
	posix.mak \
	win32.mak \
	\
	import\object.di \
	\
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
	src\core\thread.d \
	src\core\threadasm.S \
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
	src\rt\compiler.d \
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
	src\rt\memory_osx.c \
	src\rt\memset.d \
	src\rt\minit.asm \
	src\rt\monitor.c \
	src\rt\monitor_.d \
	src\rt\obj.d \
	src\rt\qsort.d \
	src\rt\qsort2.d \
	src\rt\switch_.d \
	src\rt\tls.S \
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
	src\rt\obj.d \
	src\rt\qsort.d \
	src\rt\switch_.d \
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
	$(IMPDIR)\core\atomic.di \
	$(IMPDIR)\core\bitop.di \
	$(IMPDIR)\core\cpuid.di \
	$(IMPDIR)\core\demangle.di \
	$(IMPDIR)\core\exception.di \
	$(IMPDIR)\core\math.di \
	$(IMPDIR)\core\memory.di \
	$(IMPDIR)\core\runtime.di \
	$(IMPDIR)\core\thread.di \
	$(IMPDIR)\core\time.di \
	$(IMPDIR)\core\vararg.di \
	\
	$(IMPDIR)\core\stdc\complex.di \
	$(IMPDIR)\core\stdc\config.di \
	$(IMPDIR)\core\stdc\ctype.di \
	$(IMPDIR)\core\stdc\errno.di \
	$(IMPDIR)\core\stdc\fenv.di \
	$(IMPDIR)\core\stdc\float_.di \
	$(IMPDIR)\core\stdc\inttypes.di \
	$(IMPDIR)\core\stdc\limits.di \
	$(IMPDIR)\core\stdc\locale.di \
	$(IMPDIR)\core\stdc\math.di \
	$(IMPDIR)\core\stdc\signal.di \
	$(IMPDIR)\core\stdc\stdarg.di \
	$(IMPDIR)\core\stdc\stddef.di \
	$(IMPDIR)\core\stdc\stdint.di \
	$(IMPDIR)\core\stdc\stdio.di \
	$(IMPDIR)\core\stdc\stdlib.di \
	$(IMPDIR)\core\stdc\string.di \
	$(IMPDIR)\core\stdc\tgmath.di \
	$(IMPDIR)\core\stdc\time.di \
	$(IMPDIR)\core\stdc\wchar_.di \
	$(IMPDIR)\core\stdc\wctype.di \
	\
	$(IMPDIR)\core\sync\barrier.di \
	$(IMPDIR)\core\sync\condition.di \
	$(IMPDIR)\core\sync\config.di \
	$(IMPDIR)\core\sync\exception.di \
	$(IMPDIR)\core\sync\mutex.di \
	$(IMPDIR)\core\sync\rwmutex.di \
	$(IMPDIR)\core\sync\semaphore.di \
	\
	$(IMPDIR)\core\sys\osx\mach\kern_return.di \
	$(IMPDIR)\core\sys\osx\mach\port.di \
	$(IMPDIR)\core\sys\osx\mach\semaphore.di \
	$(IMPDIR)\core\sys\osx\mach\thread_act.di \
	\
	$(IMPDIR)\core\sys\posix\arpa\inet.di \
	$(IMPDIR)\core\sys\posix\config.di \
	$(IMPDIR)\core\sys\posix\dirent.di \
	$(IMPDIR)\core\sys\posix\dlfcn.di \
	$(IMPDIR)\core\sys\posix\fcntl.di \
	$(IMPDIR)\core\sys\posix\inttypes.di \
	$(IMPDIR)\core\sys\posix\netdb.di \
	$(IMPDIR)\core\sys\posix\poll.di \
	$(IMPDIR)\core\sys\posix\pthread.di \
	$(IMPDIR)\core\sys\posix\pwd.di \
	$(IMPDIR)\core\sys\posix\sched.di \
	$(IMPDIR)\core\sys\posix\semaphore.di \
	$(IMPDIR)\core\sys\posix\setjmp.di \
	$(IMPDIR)\core\sys\posix\signal.di \
	$(IMPDIR)\core\sys\posix\stdio.di \
	$(IMPDIR)\core\sys\posix\stdlib.di \
	$(IMPDIR)\core\sys\posix\termios.di \
	$(IMPDIR)\core\sys\posix\time.di \
	$(IMPDIR)\core\sys\posix\ucontext.di \
	$(IMPDIR)\core\sys\posix\unistd.di \
	$(IMPDIR)\core\sys\posix\utime.di \
	\
	$(IMPDIR)\core\sys\posix\net\if_.di \
	\
	$(IMPDIR)\core\sys\posix\netinet\in_.di \
	$(IMPDIR)\core\sys\posix\netinet\tcp.di \
	\
	$(IMPDIR)\core\sys\posix\sys\ipc.di \
	$(IMPDIR)\core\sys\posix\sys\mman.di \
	$(IMPDIR)\core\sys\posix\sys\select.di \
	$(IMPDIR)\core\sys\posix\sys\shm.di \
	$(IMPDIR)\core\sys\posix\sys\socket.di \
	$(IMPDIR)\core\sys\posix\sys\stat.di \
	$(IMPDIR)\core\sys\posix\sys\time.di \
	$(IMPDIR)\core\sys\posix\sys\types.di \
	$(IMPDIR)\core\sys\posix\sys\uio.di \
	$(IMPDIR)\core\sys\posix\sys\wait.di \
	\
	$(IMPDIR)\core\sys\windows\dbghelp.di \
	$(IMPDIR)\core\sys\windows\dll.di \
	$(IMPDIR)\core\sys\windows\stacktrace.di \
	$(IMPDIR)\core\sys\windows\threadaux.di \
	$(IMPDIR)\core\sys\windows\windows.di

######################## Doc .html file generation ##############################

doc: $(DOCS)

$(DOCDIR)\object.html : src\object_.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_atomic.html : src\core\atomic.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_bitop.html : src\core\bitop.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_cpuid.html : src\core\cpuid.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_demangle.html : src\core\demangle.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_exception.html : src\core\exception.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_math.html : src\core\math.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_memory.html : src\core\memory.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_runtime.html : src\core\runtime.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_thread.html : src\core\thread.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_time.html : src\core\time.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_vararg.html : src\core\vararg.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_barrier.html : src\core\sync\barrier.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_condition.html : src\core\sync\condition.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_config.html : src\core\sync\config.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_exception.html : src\core\sync\exception.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_mutex.html : src\core\sync\mutex.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_rwmutex.html : src\core\sync\rwmutex.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_sync_semaphore.html : src\core\sync\semaphore.d
	$(DMD) -c -d -o- -Isrc -Iimport -Df$@ $(DOCFMT) $**

######################## Header .di file generation ##############################

import: $(IMPORTS)

$(IMPDIR)\core\atomic.di : src\core\atomic.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\bitop.di : src\core\bitop.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\cpuid.di : src\core\cpuid.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\demangle.di : src\core\demangle.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\exception.di : src\core\exception.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\math.di : src\core\math.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\memory.di : src\core\memory.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\runtime.di : src\core\runtime.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\thread.di : src\core\thread.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\time.di : src\core\time.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\vararg.di : src\core\vararg.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\complex.di : src\core\stdc\complex.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\config.di : src\core\stdc\config.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\ctype.di : src\core\stdc\ctype.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\errno.di : src\core\stdc\errno.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\fenv.di : src\core\stdc\fenv.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\float_.di : src\core\stdc\float_.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\inttypes.di : src\core\stdc\inttypes.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\limits.di : src\core\stdc\limits.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\locale.di : src\core\stdc\locale.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\math.di : src\core\stdc\math.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\signal.di : src\core\stdc\signal.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\stdarg.di : src\core\stdc\stdarg.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\stddef.di : src\core\stdc\stddef.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\stdint.di : src\core\stdc\stdint.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\stdio.di : src\core\stdc\stdio.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\stdlib.di : src\core\stdc\stdlib.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\string.di : src\core\stdc\string.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\tgmath.di : src\core\stdc\tgmath.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\time.di : src\core\stdc\time.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\wchar_.di : src\core\stdc\wchar_.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\stdc\wctype.di : src\core\stdc\wctype.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\barrier.di : src\core\sync\barrier.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\condition.di : src\core\sync\condition.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\config.di : src\core\sync\config.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\exception.di : src\core\sync\exception.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\mutex.di : src\core\sync\mutex.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\rwmutex.di : src\core\sync\rwmutex.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\semaphore.di : src\core\sync\semaphore.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\osx\mach\kern_return.di : src\core\sys\osx\mach\kern_return.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\osx\mach\port.di : src\core\sys\osx\mach\port.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\osx\mach\semaphore.di : src\core\sys\osx\mach\semaphore.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\osx\mach\thread_act.di : src\core\sys\osx\mach\thread_act.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\arpa\inet.di : src\core\sys\posix\arpa\inet.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\config.di : src\core\sys\posix\config.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\dirent.di : src\core\sys\posix\dirent.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\dlfcn.di : src\core\sys\posix\dlfcn.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\fcntl.di : src\core\sys\posix\fcntl.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\inttypes.di : src\core\sys\posix\inttypes.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\netdb.di : src\core\sys\posix\netdb.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\net\if_.di : src\core\sys\posix\net\if_.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\netinet\in_.di : src\core\sys\posix\netinet\in_.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\netinet\tcp.di : src\core\sys\posix\netinet\tcp.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\poll.di : src\core\sys\posix\poll.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\pthread.di : src\core\sys\posix\pthread.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\pwd.di : src\core\sys\posix\pwd.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\sched.di : src\core\sys\posix\sched.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\semaphore.di : src\core\sys\posix\semaphore.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\setjmp.di : src\core\sys\posix\setjmp.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\signal.di : src\core\sys\posix\signal.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\stdio.di : src\core\sys\posix\stdio.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\stdlib.di : src\core\sys\posix\stdlib.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\sys\ipc.di : src\core\sys\posix\sys\ipc.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\sys\mman.di : src\core\sys\posix\sys\mman.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\sys\select.di : src\core\sys\posix\sys\select.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\sys\shm.di : src\core\sys\posix\sys\shm.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\sys\socket.di : src\core\sys\posix\sys\socket.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\sys\stat.di : src\core\sys\posix\sys\stat.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\sys\time.di : src\core\sys\posix\sys\time.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\sys\types.di : src\core\sys\posix\sys\types.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\sys\uio.di : src\core\sys\posix\sys\uio.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\sys\wait.di : src\core\sys\posix\sys\wait.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\termios.di : src\core\sys\posix\termios.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\time.di : src\core\sys\posix\time.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\ucontext.di : src\core\sys\posix\ucontext.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\unistd.di : src\core\sys\posix\unistd.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\posix\utime.di : src\core\sys\posix\utime.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\windows\dbghelp.di : src\core\sys\windows\dbghelp.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**
	
$(IMPDIR)\core\sys\windows\dll.di : src\core\sys\windows\dll.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\windows\stacktrace.di : src\core\sys\windows\stacktrace.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**
	
$(IMPDIR)\core\sys\windows\threadaux.di : src\core\sys\windows\threadaux.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sys\windows\windows.di : src\core\sys\windows\windows.d
	$(DMD) -c -d -o- -Isrc -Iimport -Hf$@ $**

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
	$(DMD) $(UDFLAGS) -L/co -unittest src\unittest.d $(SRCS) $(DRUNTIME) -debuglib=$(DRUNTIME) -defaultlib=$(DRUNTIME)

zip: druntime.zip

druntime.zip:
	del druntime.zip
	zip32 -u druntime $(MANIFEST) $(DOCS) $(IMPORTS) src\rt\minit.obj

install: druntime.zip
	unzip -o druntime.zip -d \dmd2\src\druntime

clean:
	del $(DOCS) $(IMPORTS) $(DRUNTIME) $(OBJS_TO_DELETE) $(GCSTUB)
