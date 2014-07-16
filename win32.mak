# Makefile to build D runtime library druntime.lib for Win32

MODEL=32

DMD=dmd

CC=dmc

DOCDIR=doc
IMPDIR=import

DFLAGS=-m$(MODEL) -O -release -inline -w -Isrc -Iimport
UDFLAGS=-m$(MODEL) -O -release -w -Isrc -Iimport
DDOCFLAGS=-c -w -o- -Isrc -Iimport -version=CoreDdoc

CFLAGS=

DRUNTIME_BASE=druntime
DRUNTIME=lib\$(DRUNTIME_BASE).lib
GCSTUB=lib\gcstub.obj

DOCFMT=

target : import copydir copy $(DRUNTIME) $(GCSTUB)

$(mak\COPY)
$(mak\DOCS)
$(mak\IMPORTS)
$(mak\MANIFEST)
$(mak\SRCS)

# NOTE: trace.d and cover.d are not necessary for a successful build
#       as both are used for debugging features (profiling and coverage)
# NOTE: a pre-compiled minit.obj has been provided in dmd for Win32 and
#       minit.asm is not used by dmd for Linux

OBJS= errno_c.obj src\rt\minit.obj
OBJS_TO_DELETE= errno_c.obj

######################## Doc .html file generation ##############################

doc: $(DOCS)

$(DOCDIR)\object.html : src\object_.d
	$(DMD) $(DDOCFLAGS) -Df$@ $(DOCFMT) $**

$(DOCDIR)\core_atomic.html : src\core\atomic.d
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
	mkdir $(IMPDIR)\core\stdc
	mkdir $(IMPDIR)\core\internal
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

$(IMPDIR)\object.di : src\object.di
	copy $** $@

$(IMPDIR)\core\atomic.d : src\core\atomic.d
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

$(IMPDIR)\core\internal\convert.d : src\core\internal\convert.d
	copy $** $@

$(IMPDIR)\core\internal\hash.d : src\core\internal\hash.d
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

$(IMPDIR)\core\sys\freebsd\dlfcn.d : src\core\sys\freebsd\dlfcn.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\execinfo.d : src\core\sys\freebsd\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\time.d : src\core\sys\freebsd\time.d
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

$(IMPDIR)\core\sys\linux\link.d : src\core\sys\linux\link.d
	copy $** $@

$(IMPDIR)\core\sys\linux\termios.d : src\core\sys\linux\termios.d
	copy $** $@

$(IMPDIR)\core\sys\linux\time.d : src\core\sys\linux\time.d
	copy $** $@

$(IMPDIR)\core\sys\linux\tipc.d : src\core\sys\linux\tipc.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\inotify.d : src\core\sys\linux\sys\inotify.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\mman.d : src\core\sys\linux\sys\mman.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\signalfd.d : src\core\sys\linux\sys\signalfd.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\xattr.d : src\core\sys\linux\sys\xattr.d
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

$(IMPDIR)\core\sys\posix\syslog.d : src\core\sys\posix\syslog.d
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

$(IMPDIR)\core\sys\solaris\execinfo.d : src\core\sys\solaris\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\procset.d : src\core\sys\solaris\sys\procset.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\types.d : src\core\sys\solaris\sys\types.d
	copy $** $@

$(IMPDIR)\core\sys\solaris\sys\priocntl.d : src\core\sys\solaris\sys\priocntl.d
	copy $** $@

$(IMPDIR)\core\sys\windows\com.d : src\core\sys\windows\com.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dbghelp.d : src\core\sys\windows\dbghelp.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dll.d : src\core\sys\windows\dll.d
	copy $** $@

$(IMPDIR)\core\sys\windows\stacktrace.d : src\core\sys\windows\stacktrace.d
	copy $** $@

$(IMPDIR)\core\sys\windows\stat.d : src\core\sys\windows\stat.d
	copy $** $@

$(IMPDIR)\core\sys\windows\threadaux.d : src\core\sys\windows\threadaux.d
	copy $** $@

$(IMPDIR)\core\sys\windows\windows.d : src\core\sys\windows\windows.d
	copy $** $@

$(IMPDIR)\etc\linux\memoryerror.d : src\etc\linux\memoryerror.d
	copy $** $@

################### C\ASM Targets ############################

errno_c.obj : src\core\stdc\errno.c
	$(CC) -c $(CFLAGS) src\core\stdc\errno.c -oerrno_c.obj

src\rt\minit.obj : src\rt\minit.asm
	$(CC) -c $(CFLAGS) src\rt\minit.asm

################### gcstub generation #########################

$(GCSTUB) : src\gcstub\gc.d win$(MODEL).mak
	$(DMD) -c -of$(GCSTUB) src\gcstub\gc.d $(DFLAGS)

################### Library generation #########################

$(DRUNTIME): $(OBJS) $(SRCS) win$(MODEL).mak
	$(DMD) -lib -of$(DRUNTIME) -Xfdruntime.json $(DFLAGS) $(SRCS) $(OBJS)

unittest : $(SRCS) $(DRUNTIME) src\unittest.d
	$(DMD) $(UDFLAGS) -L/co -unittest src\unittest.d $(SRCS) $(DRUNTIME) -debuglib=$(DRUNTIME) -defaultlib=$(DRUNTIME)
	unittest

zip: druntime.zip

druntime.zip: import
	del druntime.zip
	zip32 -T -ur druntime $(MANIFEST) $(IMPDIR) src\rt\minit.obj

install: druntime.zip
	unzip -o druntime.zip -d \dmd2\src\druntime

clean:
	del $(DRUNTIME) $(OBJS_TO_DELETE) $(GCSTUB)
	rmdir /S /Q $(DOCDIR) $(IMPDIR)
