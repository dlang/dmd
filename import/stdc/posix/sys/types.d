/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module stdc.posix.sys.types;

private import stdc.posix.config;
private import stdc.stdint;
public import stdc.stddef; // for size_t
public import stdc.time;   // for clock_t, time_t

extern (C):

//
// Required
//
/*
blkcnt_t
blksize_t
dev_t
gid_t
ino_t
mode_t
nlink_t
off_t
pid_t
size_t
ssize_t
time_t
uid_t
*/

version( linux )
{
  static if( __USE_FILE_OFFSET64 )
  {
    alias long      blkcnt_t;
    alias ulong     ino_t;
    alias long      off_t;
  }
  else
  {
    alias c_long    blkcnt_t;
    alias c_ulong   ino_t;
    alias c_long    off_t;
  }
    alias c_long    blksize_t;
    alias ulong     dev_t;
    alias uint      gid_t;
    alias uint      mode_t;
    alias c_ulong   nlink_t;
    alias int       pid_t;
    //size_t (defined in stdc.stddef)
    alias c_long    ssize_t;
    //time_t (defined in stdc.time)
    alias uint      uid_t;
}
else version( darwin )
{
    alias long      blkcnt_t;
    alias int       blksize_t;
    alias int       dev_t;
    alias uint      gid_t;
    alias uint      ino_t;
    alias ushort    mode_t;
    alias ushort    nlink_t;
    alias long      off_t;
    alias int       pid_t;
    //size_t (defined in stdc.stddef)
    alias size_t    ssize_t;
    //time_t (defined in stdc.time)
    alias uint      uid_t;
}
else version( freebsd )
{
    alias long      blkcnt_t;
    alias uint      blksize_t;
    alias uint      dev_t;
    alias uint      gid_t;
    alias uint      ino_t;
    alias ushort    mode_t;
    alias ushort    nlink_t;
    alias long      off_t;
    alias int       pid_t;
    //size_t (defined in stdc.stddef)
    alias size_t    ssize_t;
    //time_t (defined in stdc.time)
    alias uint      uid_t;
}

//
// XOpen (XSI)
//
/*
clock_t
fsblkcnt_t
fsfilcnt_t
id_t
key_t
suseconds_t
useconds_t
*/

version( linux )
{
  static if( __USE_FILE_OFFSET64 )
  {
    alias ulong     fsblkcnt_t;
    alias ulong     fsfilcnt_t;
  }
  else
  {
    alias c_ulong   fsblkcnt_t;
    alias c_ulong   fsfilcnt_t;
  }
    // clock_t (defined in stdc.time)
    alias uint      id_t;
    alias int       key_t;
    alias c_long    suseconds_t;
    alias uint      useconds_t;
}
else version( darwin )
{
    //clock_t
    alias uint  fsblkcnt_t;
    alias uint  fsfilcnt_t;
    alias uint  id_t;
    // key_t
    alias int   suseconds_t;
    alias uint  useconds_t;
}
else version( freebsd )
{
    //clock_t
    alias ulong fsblkcnt_t;
    alias ulong fsfilcnt_t;
    alias long  id_t;
    // key_t
    alias c_long   suseconds_t; // C long
    alias uint  useconds_t; // C unsigned int
}

//
// Thread (THR)
//
/*
pthread_attr_t
pthread_cond_t
pthread_condattr_t
pthread_key_t
pthread_mutex_t
pthread_mutexattr_t
pthread_once_t
pthread_rwlock_t
pthread_rwlockattr_t
pthread_t
*/

version( linux )
{
    private struct __sched_param
    {
        int __sched_priority;
    }

    struct pthread_attr_t
    {
        int             __detachstate;
        int             __schedpolicy;
        __sched_param   __schedparam;
        int             __inheritsched;
        int             __scope;
        size_t          __guardsize;
        int             __stackaddr_set;
        void*           __stackaddr;
        size_t          __stacksize;
    }

    private alias int __atomic_lock_t;

    private struct _pthread_fastlock
    {
        c_long          __status;
        __atomic_lock_t __spinlock;
    }

    private alias void* _pthread_descr;

    private alias long __pthread_cond_align_t;

    struct pthread_cond_t
    {
        _pthread_fastlock       __c_lock;
        _pthread_descr          __c_waiting;
        char[48 -
             _pthread_fastlock.sizeof -
             _pthread_descr.sizeof -
             __pthread_cond_align_t.sizeof]
                                __padding;
        __pthread_cond_align_t  __align;
    }

    struct pthread_condattr_t
    {
        int __dummy;
    }

    alias uint pthread_key_t;

    struct pthread_mutex_t
    {
        int                 __m_reserved;
        int                 __m_count;
        _pthread_descr      __m_owner;
        int                 __m_kind;
        _pthread_fastlock   __m_lock;
    }

    struct pthread_mutexattr_t
    {
        int __mutexkind;
    }

    alias int pthread_once_t;

    struct pthread_rwlock_t
    {
        _pthread_fastlock   __rw_lock;
        int                 __rw_readers;
        _pthread_descr      __rw_writer;
        _pthread_descr      __rw_read_waiting;
        _pthread_descr      __rw_write_waiting;
        int                 __rw_kind;
        int                 __rw_pshared;
    }

    struct pthread_rwlockattr_t
    {
        int __lockkind;
        int __pshared;
    }

    alias c_ulong pthread_t;
}
else version( darwin )
{
    private
    {
        // #if defined(__LP64__)
        // FIXME: what is LP64, is it important enough to be included?
        version( LP64 )
        {
            const __PTHREAD_SIZE__              = 1168;
            const __PTHREAD_ATTR_SIZE__         = 56;
            const __PTHREAD_MUTEXATTR_SIZE__    = 8;
            const __PTHREAD_MUTEX_SIZE__        = 56;
            const __PTHREAD_CONDATTR_SIZE__     = 8;
            const __PTHREAD_COND_SIZE__         = 40;
            const __PTHREAD_ONCE_SIZE__         = 8;
            const __PTHREAD_RWLOCK_SIZE__       = 192;
            const __PTHREAD_RWLOCKATTR_SIZE__   = 16;
        }
        else
        {
            const __PTHREAD_SIZE__              = 596;
            const __PTHREAD_ATTR_SIZE__         = 36;
            const __PTHREAD_MUTEXATTR_SIZE__    = 8;
            const __PTHREAD_MUTEX_SIZE__        = 40;
            const __PTHREAD_CONDATTR_SIZE__     = 4;
            const __PTHREAD_COND_SIZE__         = 24;
            const __PTHREAD_ONCE_SIZE__         = 4;
            const __PTHREAD_RWLOCK_SIZE__       = 124;
            const __PTHREAD_RWLOCKATTR_SIZE__   = 12;
        }
    }

    struct pthread_handler_rec
    {
      void function(void*)  __routine;
      void*                 __arg;
      pthread_handler_rec*  __next;
    }

    struct pthread_attr_t
    {
        c_long                              __sig;
        byte[__PTHREAD_ATTR_SIZE__]         __opaque;
    }

    struct pthread_cond_t
    {
        c_long                              __sig;
        byte[__PTHREAD_COND_SIZE__]         __opaque;
    }

    struct pthread_condattr_t
    {
        c_long                              __sig;
        byte[__PTHREAD_CONDATTR_SIZE__]     __opaque;
    }

    alias c_ulong pthread_key_t;

    struct pthread_mutex_t
    {
        c_long                              __sig;
        byte[__PTHREAD_MUTEX_SIZE__]        __opaque;
    }

    struct pthread_mutexattr_t
    {
        c_long                              __sig;
        byte[__PTHREAD_MUTEXATTR_SIZE__]    __opaque;
    }

    struct pthread_once_t
    {
        c_long                              __sig;
        byte[__PTHREAD_ONCE_SIZE__]         __opaque;
    }

    struct pthread_rwlock_t
    {
        c_long                              __sig;
        byte[__PTHREAD_RWLOCK_SIZE__]       __opaque;
    }

    struct pthread_rwlockattr_t
    {
        c_long                             __sig;
        byte[__PTHREAD_RWLOCKATTR_SIZE__]   __opaque;
    }

    private struct _opaque_pthread_t
    {
        c_long                  __sig;
        pthread_handler_rec*    __cleanup_stack;
        byte[__PTHREAD_SIZE__]  __opaque;
    }

    alias _opaque_pthread_t* pthread_t;
}
else version( freebsd )
{
    struct pthread;

    /*

    {

        c_long                  tid;
        umutex                  lock;
        umtx_t                  cycle;
        int                     locklevel; // C int
        int                     critical_count; // C int
        int                     sigblock; // C int
        TAILQ_ENTRY(pthread)    tle;
        TAILQ_ENTRY(pthread)    gcle;
        LIST_ENTRY(pthread)     hle;
        int                     refcount; // C int
    }
    */

    alias pthread* pthread_t;
}

//
// Barrier (BAR)
//
/*
pthread_barrier_t
pthread_barrierattr_t
*/

version( linux )
{
    struct pthread_barrier_t
    {
        _pthread_fastlock   __ba_lock;
        int                 __ba_required;
        int                 __ba_present;
        _pthread_descr      __ba_waiting;
    }

    struct pthread_barrierattr_t
    {
        int __pshared;
    }
}
else version( freebsd )
{
    struct pthread_barrier {
        umutex                  b_lock;
        ucond                   b_cv;
        long                    b_cycle; // volatile
        int                     b_count; // volatile C int
        int                     b_waiters;  // volatile C int
    }

    alias pthread_barrier* pthread_barrier_t;

    struct pthread_barrierattr
    {
        int             pshared;
    }

    alias pthread_barrierattr* pthread_barrierattr_t;
}

//
// Spin (SPN)
//
/*
pthread_spinlock_t
*/

version( linux )
{
    alias int pthread_spinlock_t; // volatile
}
else version( darwin )
{
    struct pthread_spinlock_t;
}
else version( freebsd )
{
    private struct pthread_spinlock;

    alias pthread_spinlock* pthread_spinlock_t;
}

//
// Timer (TMR)
//
/*
clockid_t
timer_t
*/

//
// Trace (TRC)
//
/*
trace_attr_t
trace_event_id_t
trace_event_set_t
trace_id_t
*/
