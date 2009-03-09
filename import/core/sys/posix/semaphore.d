/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module core.sys.posix.semaphore;

private import core.sys.posix.config;
private import core.sys.posix.time;

extern (C):

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
else version( freebsd )
{
    enum SEM_MAGIC  = 0x09fa4012;
    enum SEM_USER   = 0;

    alias void* sem_t;

    enum SEM_FAILED = cast(sem_t*) null;
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
else version( freebsd )
{
    int sem_timedwait(sem_t*, in timespec*);
}
