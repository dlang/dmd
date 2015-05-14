/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sean Kelly, Alex Rønne Petersen
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.semaphore;

private import core.sys.posix.config;
private import core.sys.posix.time;

version (Posix):
extern (C):
nothrow:
@nogc:

//
// Required
//
/*
sem_t
SEM_FAILED

int sem_close(sem_t*);
int sem_destroy(sem_t*);
int sem_getvalue(sem_t*, int*);
int sem_init(sem_t*, int, uint);
sem_t* sem_open(in char*, int, ...);
int sem_post(sem_t*);
int sem_trywait(sem_t*);
int sem_unlink(in char*);
int sem_wait(sem_t*);
*/

version( linux )
{
    private alias int __atomic_lock_t;

    private struct _pthread_fastlock
    {
      c_long            __status;
      __atomic_lock_t   __spinlock;
    }

    struct sem_t
    {
      _pthread_fastlock __sem_lock;
      int               __sem_value;
      void*             __sem_waiting;
    }

    enum SEM_FAILED = cast(sem_t*) null;
}
else version( OSX )
{
    alias int sem_t;

    enum SEM_FAILED = cast(sem_t*) null;
}
else version( FreeBSD )
{
    // FBSD-9.0 definition
    struct sem_t
    {
        uint _magic;
        struct _usem
        {
            shared uint _has_waiters;
            shared uint _count;
            uint _flags;
        } _usem _kern;
    }

    enum SEM_FAILED = cast(sem_t*) null;
}
else version (Solaris)
{
    struct sem_t
    {
        uint sem_count;
        ushort sem_type;
        ushort sem_magic;
        ulong[3] sem_pad1;
        ulong[2] sem_pad2;
    }

    enum SEM_FAILED = cast(sem_t*)-1;
}
else version( Android )
{
    struct sem_t
    {
        uint count; //volatile
    }

    enum SEM_FAILED = null;
}
else
{
    static assert(false, "Unsupported platform");
}

int sem_close(sem_t*);
int sem_destroy(sem_t*);
int sem_getvalue(sem_t*, int*);
int sem_init(sem_t*, int, uint);
sem_t* sem_open(in char*, int, ...);
int sem_post(sem_t*);
int sem_trywait(sem_t*);
int sem_unlink(in char*);
int sem_wait(sem_t*);

//
// Timeouts (TMO)
//
/*
int sem_timedwait(sem_t*, in timespec*);
*/

version( linux )
{
    int sem_timedwait(sem_t*, in timespec*);
}
else version( OSX )
{
    int sem_timedwait(sem_t*, in timespec*);
}
else version( FreeBSD )
{
    int sem_timedwait(sem_t*, in timespec*);
}
else version (Solaris)
{
    int sem_timedwait(sem_t*, in timespec*);
}
else version( Android )
{
    int sem_timedwait(sem_t*, in timespec*);
}
else
{
    static assert(false, "Unsupported platform");
}
