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
int posix_spawnattr_getschedparam(const posix_spawnattr_t*, sched_param*);
int posix_spawnattr_getschedpolicy(const posix_spawnattr_t*, int*);
int posix_spawnattr_getsigdefault(const posix_spawnattr_t*, sigset_t*);
int posix_spawnattr_getsigmask(const posix_spawnattr_t*, sigset_t*);
int posix_spawnattr_init(posix_spawnattr_t*);
int posix_spawnattr_setflags(posix_spawnattr_t*, short);
int posix_spawnattr_setpgroup(posix_spawnattr_t*, pid_t);
int posix_spawnattr_setschedparam(posix_spawnattr_t*, const sched_param*);
int posix_spawnattr_setschedpolicy(posix_spawnattr_t*, int);
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

    struct __spawn_action
    {
        enum tag_t
        {
            spawn_do_close,
            spawn_do_dup2,
            spawn_do_open
        }

        struct close_action_t
        {
            int fd;
        }

        struct dup2_action_t
        {
            int fd;
            int newfd;
        }

        struct open_action_t
        {
            int fd;
            char*path;
            int oflag;
            mode_t mode;
        }

        tag_t tag;

        union
        {
            close_action_t close_action;
            dup2_action_t dup2_action;
            open_action_t open_action;
        }
    }

    struct posix_spawn_file_actions_t
    {
        int __allocated;
        int __used;
        __spawn_action* __actions;
        int[16] __pad;
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
}
