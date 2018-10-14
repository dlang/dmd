/**
 * D header file for spawn.h.
 *
 * Copyright: Copyright (C) 2018 by The D Language Foundation, All Rights Reserved
 * Authors:   Petar Kirov
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/druntime/blob/master/src/core/sys/posix/spawn.d, _spawn.d)
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module core.sys.posix.spawn;

/*
Based on the following system headers:

Glibc: https://sourceware.org/git/?p=glibc.git;a=blob;f=posix/spawn.h;hb=HEAD

Bionic libc: https://android.googlesource.com/platform/bionic.git/+/master/libc/include/spawn.h

Musl libc: https://git.musl-libc.org/cgit/musl/tree/include/spawn.h

uClibc: https://git.uclibc.org/uClibc/tree/include/spawn.h

Darwin XNU:
https://opensource.apple.com/source/xnu/xnu-4570.71.2/libsyscall/wrappers/spawn/spawn.h.auto.html
https://opensource.apple.com/source/xnu/xnu-4570.71.2/bsd/sys/spawn.h.auto.html
https://github.com/opensource-apple/xnu (GitHub mirror)

FreeBSD: https://github.com/freebsd/freebsd/blob/master/include/spawn.h
*/

version (OSX) // macOS and iOS only as this API is prohibited on WatchOS and TVOS
    version = Darwin;
else version (iOS)
    version = Darwin;

version (Posix):
public import core.sys.posix.sys.types : mode_t, pid_t;
public import core.sys.posix.signal : sigset_t;
public import core.sys.posix.sched : sched_param;

extern(C):
@nogc:
nothrow:

int posix_spawn_file_actions_addclose(posix_spawn_file_actions_t*, int);
int posix_spawn_file_actions_adddup2(posix_spawn_file_actions_t*, int, int);
int posix_spawn_file_actions_addopen(posix_spawn_file_actions_t*, int, const char*, int, mode_t);
int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t*);
int posix_spawn_file_actions_init(posix_spawn_file_actions_t*);
int posix_spawnattr_destroy(posix_spawnattr_t*);
int posix_spawnattr_getflags(const posix_spawnattr_t*, short*);
int posix_spawnattr_getpgroup(const posix_spawnattr_t*, pid_t*);

version (Darwin)
{ } // Not supported
else
{
    int posix_spawnattr_getschedparam(const posix_spawnattr_t*, sched_param*);
    int posix_spawnattr_getschedpolicy(const posix_spawnattr_t*, int*);
    int posix_spawnattr_setschedparam(posix_spawnattr_t*, const sched_param*);
    int posix_spawnattr_setschedpolicy(posix_spawnattr_t*, int);
}

int posix_spawnattr_getsigdefault(const posix_spawnattr_t*, sigset_t*);
int posix_spawnattr_getsigmask(const posix_spawnattr_t*, sigset_t*);
int posix_spawnattr_init(posix_spawnattr_t*);
int posix_spawnattr_setflags(posix_spawnattr_t*, short);
int posix_spawnattr_setpgroup(posix_spawnattr_t*, pid_t);
int posix_spawnattr_setsigdefault(posix_spawnattr_t*, const sigset_t*);
int posix_spawnattr_setsigmask(posix_spawnattr_t*, const sigset_t*);
int posix_spawn(pid_t*pid, const char* path,
                const posix_spawn_file_actions_t* file_actions,
                const posix_spawnattr_t* attrp,
                const char** argv, const char** envp);
int posix_spawnp(pid_t* pid, const char* file,
                 const posix_spawn_file_actions_t* file_actions,
                 const posix_spawnattr_t* attrp,
                 const char** argv, const char** envp);

version (linux)
{
    version (CRuntime_Glibc)
    {
        // Source: https://sourceware.org/git/?p=glibc.git;a=blob;f=posix/spawn.h;hb=HEAD
        enum
        {
            POSIX_SPAWN_RESETIDS = 0x01,
            POSIX_SPAWN_SETPGROUP = 0x02,
            POSIX_SPAWN_SETSIGDEF = 0x04,
            POSIX_SPAWN_SETSIGMASK = 0x08,
            POSIX_SPAWN_SETSCHEDPARAM = 0x10,
            POSIX_SPAWN_SETSCHEDULER = 0x20
        }
        import core.sys.posix.config : __USE_GNU;
        static if (__USE_GNU)
        {
            enum
            {
                POSIX_SPAWN_USEVFORK = 0x40,
                POSIX_SPAWN_SETSID = 0x80
            }
        }
        struct posix_spawnattr_t
        {
            short __flags;
            pid_t __pgrp;
            sigset_t __sd;
            sigset_t __ss;
            sched_param __sp;
            int __policy;
            int[16] __pad;
        }
        struct __spawn_action;
        struct posix_spawn_file_actions_t
        {
            int __allocated;
            int __used;
            __spawn_action* __actions;
            int[16] __pad;
        }
    }
    else version (CRuntime_Bionic)
    {
        // Source: https://android.googlesource.com/platform/bionic.git/+/master/libc/include/spawn.h
        enum
        {
            POSIX_SPAWN_RESETIDS = 1,
            POSIX_SPAWN_SETPGROUP = 2,
            POSIX_SPAWN_SETSIGDEF = 4,
            POSIX_SPAWN_SETSIGMASK = 8,
            POSIX_SPAWN_SETSCHEDPARAM = 16,
            POSIX_SPAWN_SETSCHEDULER = 32
        }
        import core.sys.posix.config : __USE_GNU;
        static if (__USE_GNU)
        {
            enum
            {
                POSIX_SPAWN_USEVFORK = 64,
                POSIX_SPAWN_SETSID = 128
            }
        }
        alias posix_spawnattr_t = __posix_spawnattr*;
        alias posix_spawn_file_actions_t = __posix_spawn_file_actions*;
        struct __posix_spawnattr;
        struct __posix_spawn_file_actions;
    }
    else version (CRuntime_Musl)
    {
        // Source: https://git.musl-libc.org/cgit/musl/tree/include/spawn.h
        enum
        {
            POSIX_SPAWN_RESETIDS = 1,
            POSIX_SPAWN_SETPGROUP = 2,
            POSIX_SPAWN_SETSIGDEF = 4,
            POSIX_SPAWN_SETSIGMASK = 8,
            POSIX_SPAWN_SETSCHEDPARAM = 16,
            POSIX_SPAWN_SETSCHEDULER = 32,
            POSIX_SPAWN_USEVFORK = 64,
            POSIX_SPAWN_SETSID = 128
        }
        struct posix_spawnattr_t
        {
            int __flags;
            pid_t __pgrp;
            sigset_t __def, __mask;
            int __prio, __pol;
            void* __fn;
            char[64 - (void*).sizeof] __pad;
        }
        struct posix_spawn_file_actions_t
        {
            int[2] __pad0;
            void* __actions;
            int[16] __pad;
        }
    }
    else version (CRuntime_UClibc)
    {
        // Source: https://git.uclibc.org/uClibc/tree/include/spawn.h
        enum
        {
            POSIX_SPAWN_RESETIDS = 0x01,
            POSIX_SPAWN_SETPGROUP = 0x02,
            POSIX_SPAWN_SETSIGDEF = 0x04,
            POSIX_SPAWN_SETSIGMASK = 0x08,
            POSIX_SPAWN_SETSCHEDPARAM = 0x10,
            POSIX_SPAWN_SETSCHEDULER = 0x20
        }
        import core.sys.posix.config : __USE_GNU;
        static if (__USE_GNU)
        {
            enum
            {
                POSIX_SPAWN_USEVFORK = 0x40,
            }
        }
        struct posix_spawnattr_t
        {
            short __flags;
            pid_t __pgrp;
            sigset_t __sd;
            sigset_t __ss;
            sched_param __sp;
            int __policy;
            int[16] __pad;
        }
        struct posix_spawn_file_actions_t
        {
            int __allocated;
            int __used;
            __spawn_action* __actions;
            int[16] __pad;
        }
    }
    else
        static assert(0, "Unsupported Linux libc");
}
else version (Darwin)
{
    // Sources:
    // https://opensource.apple.com/source/xnu/xnu-4570.71.2/libsyscall/wrappers/spawn/spawn.h.auto.html
    // https://opensource.apple.com/source/xnu/xnu-4570.71.2/bsd/sys/spawn.h.auto.html
    enum
    {
        POSIX_SPAWN_RESETIDS = 0x01,
        POSIX_SPAWN_SETPGROUP = 0x02,
        POSIX_SPAWN_SETSIGDEF = 0x04,
        POSIX_SPAWN_SETSIGMASK = 0x08,
        // POSIX_SPAWN_SETSCHEDPARAM = 0x10,  // not supported
        // POSIX_SPAWN_SETSCHEDULER = 0x20,   // ditto
        POSIX_SPAWN_SETEXEC = 0x40,
        POSIX_SPAWN_START_SUSPENDED = 0x80
    }
    alias posix_spawnattr_t = void*;
    alias posix_spawn_file_actions_t = void*;
}
else version (FreeBSD)
{
    // Source: https://github.com/freebsd/freebsd/blob/master/include/spawn.h
    enum
    {
        POSIX_SPAWN_RESETIDS = 0x01,
        POSIX_SPAWN_SETPGROUP = 0x02,
        POSIX_SPAWN_SETSCHEDPARAM = 0x04,
        POSIX_SPAWN_SETSCHEDULER = 0x08,
        POSIX_SPAWN_SETSIGDEF = 0x10,
        POSIX_SPAWN_SETSIGMASK = 0x20
    }
    alias posix_spawnattr_t =  void*;
    alias posix_spawn_file_actions_t =  void*;
}
else
    static assert(0, "Unsupported OS");
