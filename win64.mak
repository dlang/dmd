# Makefile to build D runtime library druntime64.lib for Win64

MODEL=64

VCDIR=\Program Files (x86)\Microsoft Visual Studio 10.0\VC
SDKDIR=\Program Files (x86)\Microsoft SDKs\Windows\v7.0A

DMD=dmd

CC="$(VCDIR)\bin\amd64\cl"
LD="$(VCDIR)\bin\amd64\link"
AR="$(VCDIR)\bin\amd64\lib"
CP=cp

DOCDIR=doc
IMPDIR=import

MAKE=make

DFLAGS=-m$(MODEL) -conf= -O -release -dip25 -inline -w -Isrc -Iimport
UDFLAGS=-m$(MODEL) -conf= -O -release -dip25 -w -Isrc -Iimport
DDOCFLAGS=-conf= -c -w -o- -Isrc -Iimport -version=CoreDdoc

#CFLAGS=/O2 /I"$(VCDIR)"\INCLUDE /I"$(SDKDIR)"\Include
CFLAGS=/Z7 /I"$(VCDIR)"\INCLUDE /I"$(SDKDIR)"\Include

DRUNTIME_BASE=druntime$(MODEL)
DRUNTIME=lib\$(DRUNTIME_BASE).lib
GCSTUB=lib\gcstub$(MODEL).obj

DOCFMT=

target : import copydir copy $(DRUNTIME) $(GCSTUB)

$(mak\COPY)
$(mak\DOCS)
$(mak\IMPORTS)
$(mak\SRCS)

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)

OBJS= errno_c_$(MODEL).obj msvc_$(MODEL).obj msvc_math_$(MODEL).obj
OBJS_TO_DELETE= errno_c_$(MODEL).obj msvc_$(MODEL).obj msvc_math_$(MODEL).obj

######################## Doc .html file generation ##############################

doc: $(DOCS)

$(DOCDIR)\object.html : src\object.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_atomic.html : src\core\atomic.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_attribute.html : src\core\attribute.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_bitop.html : src\core\bitop.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_checkedint.html : src\core\checkedint.d
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

$(DOCDIR)\core_thread.html : src\core\thread.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_time.html : src\core\time.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_vararg.html : src\core\vararg.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**


$(DOCDIR)\core_stdc_complex.html : src\core\stdc\complex.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_ctype.html : src\core\stdc\ctype.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_errno.html : src\core\stdc\errno.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_fenv.html : src\core\stdc\fenv.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_float_.html : src\core\stdc\float_.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_inttypes.html : src\core\stdc\inttypes.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_limits.html : src\core\stdc\limits.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_locale.html : src\core\stdc\locale.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_math.html : src\core\stdc\math.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_signal.html : src\core\stdc\signal.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_stdarg.html : src\core\stdc\stdarg.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_stddef.html : src\core\stdc\stddef.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_stdint.html : src\core\stdc\stdint.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_stdio.html : src\core\stdc\stdio.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_stdlib.html : src\core\stdc\stdlib.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_string.html : src\core\stdc\string.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_tgmath.html : src\core\stdc\tgmath.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_time.html : src\core\stdc\time.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_wchar_.html : src\core\stdc\wchar_.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_stdc_wctype.html : src\core\stdc\wctype.d
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

changelog.html: changelog.dd
	$(DMD) -Dfchangelog.html changelog.dd

######################## Header .di file generation ##############################

import: $(IMPORTS)

$(IMPDIR)\core\sync\barrier.di : src\core\sync\barrier.d
	$(DMD) -conf= -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\condition.di : src\core\sync\condition.d
	$(DMD) -conf= -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\config.di : src\core\sync\config.d
	$(DMD) -conf= -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\exception.di : src\core\sync\exception.d
	$(DMD) -conf= -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\mutex.di : src\core\sync\mutex.d
	$(DMD) -conf= -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\rwmutex.di : src\core\sync\rwmutex.d
	$(DMD) -conf= -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\semaphore.di : src\core\sync\semaphore.d
	$(DMD) -conf= -c -o- -Isrc -Iimport -Hf$@ $**

######################## Header .di file copy ##############################

copydir: $(IMPDIR)
	mkdir $(IMPDIR)\core\stdc
	mkdir $(IMPDIR)\core\stdcpp
	mkdir $(IMPDIR)\core\internal
	mkdir $(IMPDIR)\core\sys\darwin\mach
	mkdir $(IMPDIR)\core\sys\freebsd\sys
	mkdir $(IMPDIR)\core\sys\linux\sys
	mkdir $(IMPDIR)\core\sys\osx\mach
	mkdir $(IMPDIR)\core\sys\posix\arpa
	mkdir $(IMPDIR)\core\sys\posix\net
	mkdir $(IMPDIR)\core\sys\posix\netinet
	mkdir $(IMPDIR)\core\sys\posix\sys
	mkdir $(IMPDIR)\core\sys\solaris\sys
	mkdir $(IMPDIR)\core\sys\windows
	mkdir $(IMPDIR)\etc\linux

copy: $(COPY)

$(IMPDIR)\object.d : src\object.d
	copy $** $@
	if exist $(IMPDIR)\object.di del $(IMPDIR)\object.di

$(IMPDIR)\core\atomic.d : src\core\atomic.d
	copy $** $@

$(IMPDIR)\core\attribute.d : src\core\attribute.d
	copy $** $@

$(IMPDIR)\core\bitop.d : src\core\bitop.d
	copy $** $@

$(IMPDIR)\core\checkedint.d : src\core\checkedint.d
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

$(IMPDIR)\core\thread.d : src\core\thread.d
	copy $** $@

$(IMPDIR)\core\time.d : src\core\time.d
	copy $** $@

$(IMPDIR)\core\vararg.d : src\core\vararg.d
	copy $** $@

$(IMPDIR)\core\internal\abort.d : src\core\internal\abort.d
	copy $** $@

$(IMPDIR)\core\internal\convert.d : src\core\internal\convert.d
	copy $** $@

$(IMPDIR)\core\internal\hash.d : src\core\internal\hash.d
	copy $** $@

$(IMPDIR)\core\internal\spinlock.d : src\core\internal\spinlock.d
	copy $** $@

$(IMPDIR)\core\internal\string.d : src\core\internal\string.d
	copy $** $@

$(IMPDIR)\core\internal\traits.d : src\core\internal\traits.d
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

$(IMPDIR)\core\stdcpp\exception.d : src\core\stdcpp\exception.d
	copy $** $@

$(IMPDIR)\core\stdcpp\typeinfo.d : src\core\stdcpp\typeinfo.d
	copy $** $@

$(IMPDIR)\core\sys\darwin\execinfo.d : src\core\sys\darwin\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\darwin\pthread.d : src\core\sys\darwin\pthread.d
	copy $** $@

$(IMPDIR)\core\sys\darwin\mach\dyld.d : src\core\sys\darwin\mach\dyld.d
	copy $** $@

$(IMPDIR)\core\sys\darwin\mach\getsect.d : src\core\sys\darwin\mach\getsect.d
	copy $** $@

$(IMPDIR)\core\sys\darwin\mach\kern_return.d : src\core\sys\darwin\mach\kern_return.d
	copy $** $@

$(IMPDIR)\core\sys\darwin\mach\loader.d : src\core\sys\darwin\mach\loader.d
	copy $** $@

$(IMPDIR)\core\sys\darwin\mach\port.d : src\core\sys\darwin\mach\port.d
	copy $** $@

$(IMPDIR)\core\sys\darwin\mach\semaphore.d : src\core\sys\darwin\mach\semaphore.d
	copy $** $@

$(IMPDIR)\core\sys\darwin\mach\thread_act.d : src\core\sys\darwin\mach\thread_act.d
	copy $** $@

$(IMPDIR)\core\sys\darwin\sys\cdefs.d : src\core\sys\darwin\sys\cdefs.d
	copy $** $@

$(IMPDIR)\core\sys\darwin\sys\event.d : src\core\sys\darwin\sys\event.d
	copy $** $@

$(IMPDIR)\core\sys\darwin\sys\mman.d : src\core\sys\darwin\sys\mman.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\dlfcn.d : src\core\sys\freebsd\dlfcn.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\execinfo.d : src\core\sys\freebsd\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\pthread_np.d : src\core\sys\freebsd\pthread_np.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\time.d : src\core\sys\freebsd\time.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\cdefs.d : src\core\sys\freebsd\sys\cdefs.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\_bitset.d : src\core\sys\freebsd\sys\_bitset.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\_cpuset.d : src\core\sys\freebsd\sys\_cpuset.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\elf.d : src\core\sys\freebsd\sys\elf.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\elf_common.d : src\core\sys\freebsd\sys\elf_common.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\elf32.d : src\core\sys\freebsd\sys\elf32.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\elf64.d : src\core\sys\freebsd\sys\elf64.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\event.d : src\core\sys\freebsd\sys\event.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\link_elf.d : src\core\sys\freebsd\sys\link_elf.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\mman.d : src\core\sys\freebsd\sys\mman.d
	copy $** $@

$(IMPDIR)\core\sys\linux\config.d : src\core\sys\linux\config.d
	copy $** $@

$(IMPDIR)\core\sys\linux\dlfcn.d : src\core\sys\linux\dlfcn.d
	copy $** $@

$(IMPDIR)\core\sys\linux\elf.d : src\core\sys\linux\elf.d
	copy $** $@

$(IMPDIR)\core\sys\linux\epoll.d : src\core\sys\linux\epoll.d
	copy $** $@

$(IMPDIR)\core\sys\linux\errno.d : src\core\sys\linux\errno.d
	copy $** $@

$(IMPDIR)\core\sys\linux\execinfo.d : src\core\sys\linux\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\linux\ifaddrs.d : src\core\sys\linux\ifaddrs.d
	copy $** $@

$(IMPDIR)\core\sys\linux\fcntl.d : src\core\sys\linux\fcntl.d
	copy $** $@

$(IMPDIR)\core\sys\linux\link.d : src\core\sys\linux\link.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sched.d : src\core\sys\linux\sched.d
	copy $** $@

$(IMPDIR)\core\sys\linux\termios.d : src\core\sys\linux\termios.d
	copy $** $@

$(IMPDIR)\core\sys\linux\time.d : src\core\sys\linux\time.d
	copy $** $@

$(IMPDIR)\core\sys\linux\timerfd.d : src\core\sys\linux\timerfd.d
	copy $** $@

$(IMPDIR)\core\sys\linux\tipc.d : src\core\sys\linux\tipc.d
	copy $** $@

$(IMPDIR)\core\sys\linux\unistd.d : src\core\sys\linux\unistd.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\auxv.d : src\core\sys\linux\sys\auxv.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\inotify.d : src\core\sys\linux\sys\inotify.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\prctl.d : src\core\sys\linux\sys\prctl.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\mman.d : src\core\sys\linux\sys\mman.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\netinet\tcp.d : src\core\sys\linux\sys\netinet\tcp.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\signalfd.d : src\core\sys\linux\sys\signalfd.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\socket.d : src\core\sys\linux\sys\socket.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\sysinfo.d : src\core\sys\linux\sys\sysinfo.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\xattr.d : src\core\sys\linux\sys\xattr.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\time.d : src\core\sys\linux\sys\time.d
	copy $** $@

$(IMPDIR)\core\sys\openbsd\dlfcn.d : src\core\sys\openbsd\dlfcn.d
	copy $** $@

$(IMPDIR)\core\sys\osx\execinfo.d : src\core\sys\osx\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\osx\pthread.d : src\core\sys\osx\pthread.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\dyld.d : src\core\sys\osx\mach\dyld.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\getsect.d : src\core\sys\osx\mach\getsect.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\kern_return.d : src\core\sys\osx\mach\kern_return.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\loader.d : src\core\sys\osx\mach\loader.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\port.d : src\core\sys\osx\mach\port.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\semaphore.d : src\core\sys\osx\mach\semaphore.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\thread_act.d : src\core\sys\osx\mach\thread_act.d
	copy $** $@

$(IMPDIR)\core\sys\osx\sys\cdefs.d : src\core\sys\osx\sys\cdefs.d
	copy $** $@

$(IMPDIR)\core\sys\osx\sys\mman.d : src\core\sys\osx\sys\mman.d
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

$(IMPDIR)\core\sys\posix\grp.d : src\core\sys\posix\grp.d
	copy $** $@

$(IMPDIR)\core\sys\posix\iconv.d : src\core\sys\posix\iconv.d
	copy $** $@

$(IMPDIR)\core\sys\posix\inttypes.d : src\core\sys\posix\inttypes.d
	copy $** $@

$(IMPDIR)\core\sys\posix\libgen.d : src\core\sys\posix\libgen.d
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

$(IMPDIR)\core\sys\posix\syslog.d : src\core\sys\posix\syslog.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\filio.d : src\core\sys\posix\sys\filio.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\ioccom.d : src\core\sys\posix\sys\ioccom.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\ioctl.d : src\core\sys\posix\sys\ioctl.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\ipc.d : src\core\sys\posix\sys\ipc.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\mman.d : src\core\sys\posix\sys\mman.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\resource.d : src\core\sys\posix\sys\resource.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\select.d : src\core\sys\posix\sys\select.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\shm.d : src\core\sys\posix\sys\shm.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\socket.d : src\core\sys\posix\sys\socket.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\stat.d : src\core\sys\posix\sys\stat.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\statvfs.d : src\core\sys\posix\sys\statvfs.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\ttycom.d : src\core\sys\posix\sys\ttycom.d
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

$(IMPDIR)\core\sys\solaris\dlfcn.d : src\core\sys\solaris\dlfcn.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\elf.d : src\core\sys\solaris\elf.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\execinfo.d : src\core\sys\solaris\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\libelf.d : src\core\sys\solaris\libelf.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\link.d : src\core\sys\solaris\link.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\time.d : src\core\sys\solaris\time.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\elf.d : src\core\sys\solaris\sys\elf.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\elf_386.d : src\core\sys\solaris\sys\elf_386.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\elf_amd64.d : src\core\sys\solaris\sys\elf_amd64.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\elf_notes.d : src\core\sys\solaris\sys\elf_notes.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\elf_SPARC.d : src\core\sys\solaris\sys\elf_SPARC.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\elftypes.d : src\core\sys\solaris\sys\elftypes.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\link.d : src\core\sys\solaris\sys\link.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\procset.d : src\core\sys\solaris\sys\procset.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\types.d : src\core\sys\solaris\sys\types.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\priocntl.d : src\core\sys\solaris\sys\priocntl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\accctrl.d : src\core\sys\windows\accctrl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\aclapi.d : src\core\sys\windows\aclapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\aclui.d : src\core\sys\windows\aclui.d
	copy $** $@

$(IMPDIR)\core\sys\windows\basetsd.d : src\core\sys\windows\basetsd.d
	copy $** $@

$(IMPDIR)\core\sys\windows\basetyps.d : src\core\sys\windows\basetyps.d
	copy $** $@

$(IMPDIR)\core\sys\windows\cderr.d : src\core\sys\windows\cderr.d
	copy $** $@

$(IMPDIR)\core\sys\windows\cguid.d : src\core\sys\windows\cguid.d
	copy $** $@

$(IMPDIR)\core\sys\windows\com.d : src\core\sys\windows\com.d
	copy $** $@

$(IMPDIR)\core\sys\windows\comcat.d : src\core\sys\windows\comcat.d
	copy $** $@

$(IMPDIR)\core\sys\windows\commctrl.d : src\core\sys\windows\commctrl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\commdlg.d : src\core\sys\windows\commdlg.d
	copy $** $@

$(IMPDIR)\core\sys\windows\core.d : src\core\sys\windows\core.d
	copy $** $@

$(IMPDIR)\core\sys\windows\cpl.d : src\core\sys\windows\cpl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\cplext.d : src\core\sys\windows\cplext.d
	copy $** $@

$(IMPDIR)\core\sys\windows\custcntl.d : src\core\sys\windows\custcntl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dbghelp.d : src\core\sys\windows\dbghelp.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dbghelp_types.d : src\core\sys\windows\dbghelp_types.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dbt.d : src\core\sys\windows\dbt.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dde.d : src\core\sys\windows\dde.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ddeml.d : src\core\sys\windows\ddeml.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dhcpcsdk.d : src\core\sys\windows\dhcpcsdk.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dlgs.d : src\core\sys\windows\dlgs.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dll.d : src\core\sys\windows\dll.d
	copy $** $@

$(IMPDIR)\core\sys\windows\docobj.d : src\core\sys\windows\docobj.d
	copy $** $@

$(IMPDIR)\core\sys\windows\errorrep.d : src\core\sys\windows\errorrep.d
	copy $** $@

$(IMPDIR)\core\sys\windows\exdisp.d : src\core\sys\windows\exdisp.d
	copy $** $@

$(IMPDIR)\core\sys\windows\exdispid.d : src\core\sys\windows\exdispid.d
	copy $** $@

$(IMPDIR)\core\sys\windows\httpext.d : src\core\sys\windows\httpext.d
	copy $** $@

$(IMPDIR)\core\sys\windows\idispids.d : src\core\sys\windows\idispids.d
	copy $** $@

$(IMPDIR)\core\sys\windows\imagehlp.d : src\core\sys\windows\imagehlp.d
	copy $** $@

$(IMPDIR)\core\sys\windows\imm.d : src\core\sys\windows\imm.d
	copy $** $@

$(IMPDIR)\core\sys\windows\intshcut.d : src\core\sys\windows\intshcut.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ipexport.d : src\core\sys\windows\ipexport.d
	copy $** $@

$(IMPDIR)\core\sys\windows\iphlpapi.d : src\core\sys\windows\iphlpapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ipifcons.d : src\core\sys\windows\ipifcons.d
	copy $** $@

$(IMPDIR)\core\sys\windows\iprtrmib.d : src\core\sys\windows\iprtrmib.d
	copy $** $@

$(IMPDIR)\core\sys\windows\iptypes.d : src\core\sys\windows\iptypes.d
	copy $** $@

$(IMPDIR)\core\sys\windows\isguids.d : src\core\sys\windows\isguids.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lm.d : src\core\sys\windows\lm.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmaccess.d : src\core\sys\windows\lmaccess.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmalert.d : src\core\sys\windows\lmalert.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmapibuf.d : src\core\sys\windows\lmapibuf.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmat.d : src\core\sys\windows\lmat.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmaudit.d : src\core\sys\windows\lmaudit.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmbrowsr.d : src\core\sys\windows\lmbrowsr.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmchdev.d : src\core\sys\windows\lmchdev.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmconfig.d : src\core\sys\windows\lmconfig.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmcons.d : src\core\sys\windows\lmcons.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmerr.d : src\core\sys\windows\lmerr.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmerrlog.d : src\core\sys\windows\lmerrlog.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmmsg.d : src\core\sys\windows\lmmsg.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmremutl.d : src\core\sys\windows\lmremutl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmrepl.d : src\core\sys\windows\lmrepl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmserver.d : src\core\sys\windows\lmserver.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmshare.d : src\core\sys\windows\lmshare.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmsname.d : src\core\sys\windows\lmsname.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmstats.d : src\core\sys\windows\lmstats.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmsvc.d : src\core\sys\windows\lmsvc.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmuse.d : src\core\sys\windows\lmuse.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmuseflg.d : src\core\sys\windows\lmuseflg.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lmwksta.d : src\core\sys\windows\lmwksta.d
	copy $** $@

$(IMPDIR)\core\sys\windows\lzexpand.d : src\core\sys\windows\lzexpand.d
	copy $** $@

$(IMPDIR)\core\sys\windows\mapi.d : src\core\sys\windows\mapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\mciavi.d : src\core\sys\windows\mciavi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\mcx.d : src\core\sys\windows\mcx.d
	copy $** $@

$(IMPDIR)\core\sys\windows\mgmtapi.d : src\core\sys\windows\mgmtapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\mmsystem.d : src\core\sys\windows\mmsystem.d
	copy $** $@

$(IMPDIR)\core\sys\windows\msacm.d : src\core\sys\windows\msacm.d
	copy $** $@

$(IMPDIR)\core\sys\windows\mshtml.d : src\core\sys\windows\mshtml.d
	copy $** $@

$(IMPDIR)\core\sys\windows\mswsock.d : src\core\sys\windows\mswsock.d
	copy $** $@

$(IMPDIR)\core\sys\windows\nb30.d : src\core\sys\windows\nb30.d
	copy $** $@

$(IMPDIR)\core\sys\windows\nddeapi.d : src\core\sys\windows\nddeapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\nspapi.d : src\core\sys\windows\nspapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ntdef.d : src\core\sys\windows\ntdef.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ntdll.d : src\core\sys\windows\ntdll.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ntldap.d : src\core\sys\windows\ntldap.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ntsecapi.d : src\core\sys\windows\ntsecapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ntsecpkg.d : src\core\sys\windows\ntsecpkg.d
	copy $** $@

$(IMPDIR)\core\sys\windows\oaidl.d : src\core\sys\windows\oaidl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\objbase.d : src\core\sys\windows\objbase.d
	copy $** $@

$(IMPDIR)\core\sys\windows\objfwd.d : src\core\sys\windows\objfwd.d
	copy $** $@

$(IMPDIR)\core\sys\windows\objidl.d : src\core\sys\windows\objidl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\objsafe.d : src\core\sys\windows\objsafe.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ocidl.d : src\core\sys\windows\ocidl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\odbcinst.d : src\core\sys\windows\odbcinst.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ole.d : src\core\sys\windows\ole.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ole2.d : src\core\sys\windows\ole2.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ole2ver.d : src\core\sys\windows\ole2ver.d
	copy $** $@

$(IMPDIR)\core\sys\windows\oleacc.d : src\core\sys\windows\oleacc.d
	copy $** $@

$(IMPDIR)\core\sys\windows\oleauto.d : src\core\sys\windows\oleauto.d
	copy $** $@

$(IMPDIR)\core\sys\windows\olectl.d : src\core\sys\windows\olectl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\olectlid.d : src\core\sys\windows\olectlid.d
	copy $** $@

$(IMPDIR)\core\sys\windows\oledlg.d : src\core\sys\windows\oledlg.d
	copy $** $@

$(IMPDIR)\core\sys\windows\oleidl.d : src\core\sys\windows\oleidl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\pbt.d : src\core\sys\windows\pbt.d
	copy $** $@

$(IMPDIR)\core\sys\windows\powrprof.d : src\core\sys\windows\powrprof.d
	copy $** $@

$(IMPDIR)\core\sys\windows\prsht.d : src\core\sys\windows\prsht.d
	copy $** $@

$(IMPDIR)\core\sys\windows\psapi.d : src\core\sys\windows\psapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\rapi.d : src\core\sys\windows\rapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\ras.d : src\core\sys\windows\ras.d
	copy $** $@

$(IMPDIR)\core\sys\windows\rasdlg.d : src\core\sys\windows\rasdlg.d
	copy $** $@

$(IMPDIR)\core\sys\windows\raserror.d : src\core\sys\windows\raserror.d
	copy $** $@

$(IMPDIR)\core\sys\windows\rassapi.d : src\core\sys\windows\rassapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\reason.d : src\core\sys\windows\reason.d
	copy $** $@

$(IMPDIR)\core\sys\windows\regstr.d : src\core\sys\windows\regstr.d
	copy $** $@

$(IMPDIR)\core\sys\windows\richedit.d : src\core\sys\windows\richedit.d
	copy $** $@

$(IMPDIR)\core\sys\windows\richole.d : src\core\sys\windows\richole.d
	copy $** $@

$(IMPDIR)\core\sys\windows\rpc.d : src\core\sys\windows\rpc.d
	copy $** $@

$(IMPDIR)\core\sys\windows\rpcdce.d : src\core\sys\windows\rpcdce.d
	copy $** $@

$(IMPDIR)\core\sys\windows\rpcdce2.d : src\core\sys\windows\rpcdce2.d
	copy $** $@

$(IMPDIR)\core\sys\windows\rpcdcep.d : src\core\sys\windows\rpcdcep.d
	copy $** $@

$(IMPDIR)\core\sys\windows\rpcndr.d : src\core\sys\windows\rpcndr.d
	copy $** $@

$(IMPDIR)\core\sys\windows\rpcnsi.d : src\core\sys\windows\rpcnsi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\rpcnsip.d : src\core\sys\windows\rpcnsip.d
	copy $** $@

$(IMPDIR)\core\sys\windows\rpcnterr.d : src\core\sys\windows\rpcnterr.d
	copy $** $@

$(IMPDIR)\core\sys\windows\schannel.d : src\core\sys\windows\schannel.d
	copy $** $@

$(IMPDIR)\core\sys\windows\secext.d : src\core\sys\windows\secext.d
	copy $** $@

$(IMPDIR)\core\sys\windows\security.d : src\core\sys\windows\security.d
	copy $** $@

$(IMPDIR)\core\sys\windows\servprov.d : src\core\sys\windows\servprov.d
	copy $** $@

$(IMPDIR)\core\sys\windows\setupapi.d : src\core\sys\windows\setupapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\shellapi.d : src\core\sys\windows\shellapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\shldisp.d : src\core\sys\windows\shldisp.d
	copy $** $@

$(IMPDIR)\core\sys\windows\shlguid.d : src\core\sys\windows\shlguid.d
	copy $** $@

$(IMPDIR)\core\sys\windows\shlobj.d : src\core\sys\windows\shlobj.d
	copy $** $@

$(IMPDIR)\core\sys\windows\shlwapi.d : src\core\sys\windows\shlwapi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\snmp.d : src\core\sys\windows\snmp.d
	copy $** $@

$(IMPDIR)\core\sys\windows\sql.d : src\core\sys\windows\sql.d
	copy $** $@

$(IMPDIR)\core\sys\windows\sqlext.d : src\core\sys\windows\sqlext.d
	copy $** $@

$(IMPDIR)\core\sys\windows\sqltypes.d : src\core\sys\windows\sqltypes.d
	copy $** $@

$(IMPDIR)\core\sys\windows\sqlucode.d : src\core\sys\windows\sqlucode.d
	copy $** $@

$(IMPDIR)\core\sys\windows\sspi.d : src\core\sys\windows\sspi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\stacktrace.d : src\core\sys\windows\stacktrace.d
	copy $** $@

$(IMPDIR)\core\sys\windows\stat.d : src\core\sys\windows\stat.d
	copy $** $@

$(IMPDIR)\core\sys\windows\subauth.d : src\core\sys\windows\subauth.d
	copy $** $@

$(IMPDIR)\core\sys\windows\threadaux.d : src\core\sys\windows\threadaux.d
	copy $** $@

$(IMPDIR)\core\sys\windows\tlhelp32.d : src\core\sys\windows\tlhelp32.d
	copy $** $@

$(IMPDIR)\core\sys\windows\tmschema.d : src\core\sys\windows\tmschema.d
	copy $** $@

$(IMPDIR)\core\sys\windows\unknwn.d : src\core\sys\windows\unknwn.d
	copy $** $@

$(IMPDIR)\core\sys\windows\uuid.d : src\core\sys\windows\uuid.d
	copy $** $@

$(IMPDIR)\core\sys\windows\vfw.d : src\core\sys\windows\vfw.d
	copy $** $@

$(IMPDIR)\core\sys\windows\w32api.d : src\core\sys\windows\w32api.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winbase.d : src\core\sys\windows\winbase.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winber.d : src\core\sys\windows\winber.d
	copy $** $@

$(IMPDIR)\core\sys\windows\wincon.d : src\core\sys\windows\wincon.d
	copy $** $@

$(IMPDIR)\core\sys\windows\wincrypt.d : src\core\sys\windows\wincrypt.d
	copy $** $@

$(IMPDIR)\core\sys\windows\windef.d : src\core\sys\windows\windef.d
	copy $** $@

$(IMPDIR)\core\sys\windows\windows.d : src\core\sys\windows\windows.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winerror.d : src\core\sys\windows\winerror.d
	copy $** $@

$(IMPDIR)\core\sys\windows\wingdi.d : src\core\sys\windows\wingdi.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winhttp.d : src\core\sys\windows\winhttp.d
	copy $** $@

$(IMPDIR)\core\sys\windows\wininet.d : src\core\sys\windows\wininet.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winioctl.d : src\core\sys\windows\winioctl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winldap.d : src\core\sys\windows\winldap.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winnetwk.d : src\core\sys\windows\winnetwk.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winnls.d : src\core\sys\windows\winnls.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winnt.d : src\core\sys\windows\winnt.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winperf.d : src\core\sys\windows\winperf.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winreg.d : src\core\sys\windows\winreg.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winsock2.d : src\core\sys\windows\winsock2.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winspool.d : src\core\sys\windows\winspool.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winsvc.d : src\core\sys\windows\winsvc.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winuser.d : src\core\sys\windows\winuser.d
	copy $** $@

$(IMPDIR)\core\sys\windows\winver.d : src\core\sys\windows\winver.d
	copy $** $@

$(IMPDIR)\core\sys\windows\wtsapi32.d : src\core\sys\windows\wtsapi32.d
	copy $** $@

$(IMPDIR)\core\sys\windows\wtypes.d : src\core\sys\windows\wtypes.d
	copy $** $@

$(IMPDIR)\etc\linux\memoryerror.d : src\etc\linux\memoryerror.d
	copy $** $@

################### C\ASM Targets ############################

errno_c_$(MODEL).obj : src\core\stdc\errno.c
	$(CC) -c -Fo$@ $(CFLAGS) src\core\stdc\errno.c

msvc_$(MODEL).obj : src\rt\msvc.c win64.mak
	$(CC) -c -Fo$@ $(CFLAGS) src\rt\msvc.c

msvc_math_$(MODEL).obj : src\rt\msvc_math.c win64.mak
	$(CC) -c -Fo$@ $(CFLAGS) src\rt\msvc_math.c

################### gcstub generation #########################

$(GCSTUB) : src\gcstub\gc.d win64.mak
	$(DMD) -c -of$(GCSTUB) src\gcstub\gc.d $(DFLAGS)


################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) win64.mak
	$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

# due to -conf= on the command line, LINKCMD and LIB need to be set in the environment
unittest : $(SRCS) $(DRUNTIME)
	$(DMD) $(UDFLAGS) -version=druntime_unittest -unittest -ofunittest.exe -main $(SRCS) $(DRUNTIME) -debuglib=$(DRUNTIME) -defaultlib=$(DRUNTIME) user32.lib
	unittest

################### Win32 COFF support #########################

# default to 32-bit compiler relative to 64-bit compiler, link and lib are architecture agnostic
CC32=$(CC)\..\..\cl

druntime32mscoff:
	$(MAKE) -f win64.mak "DMD=$(DMD)" MODEL=32mscoff "CC=\$(CC32)"\"" "AR=\$(AR)"\"" "VCDIR=$(VCDIR)" "SDKDIR=$(SDKDIR)"

unittest32mscoff:
	$(MAKE) -f win64.mak "DMD=$(DMD)" MODEL=32mscoff "CC=\$(CC32)"\"" "AR=\$(AR)"\"" "VCDIR=$(VCDIR)" "SDKDIR=$(SDKDIR)" unittest

################### zip/install/clean ##########################

zip: druntime.zip

druntime.zip: import
	del druntime.zip
	git ls-tree --name-only -r HEAD >MANIFEST.tmp
	zip32 -T -ur druntime @MANIFEST.tmp
	del MANIFEST.tmp

install: druntime.zip
	unzip -o druntime.zip -d \dmd2\src\druntime

clean:
	del $(DRUNTIME) $(OBJS_TO_DELETE) $(GCSTUB)
	rmdir /S /Q $(DOCDIR) $(IMPDIR)

auto-tester-build: target

auto-tester-test: unittest

