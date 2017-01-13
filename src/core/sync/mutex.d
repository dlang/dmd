/**
 * The mutex module provides a primitive for maintaining mutually exclusive
 * access.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Sean Kelly
 * Source:    $(DRUNTIMESRC core/sync/_mutex.d)
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sync.mutex;


public import core.sync.exception;

version (Windows)
{
    private import core.sys.windows.windows;
}
else version (Posix)
{
    private import core.sys.posix.pthread;
}
else
{
    static assert(false, "Platform not supported");
}

////////////////////////////////////////////////////////////////////////////////
// Mutex
//
// void lock();
// void unlock();
// bool tryLock();
////////////////////////////////////////////////////////////////////////////////


/**
 * This class represents a general purpose, recursive mutex.
 *
 * Implemented using pthread_mutex on Posix and CRITICAL_SECTION
 * on Windows.
 */
class Mutex :
    Object.Monitor
{
    ////////////////////////////////////////////////////////////////////////////
    // Initialization
    ////////////////////////////////////////////////////////////////////////////


    /**
     * Initializes a mutex object.
     *
     */
    this() @trusted nothrow @nogc
    {
        this(true);
    }

    /// ditto
    this() shared @trusted nothrow @nogc
    {
        this(true);
    }

    // Undocumented, useful only in Mutex.this().
    private this(this Q)(bool _unused_) @trusted nothrow @nogc
        if (is(Q == Mutex) || is(Q == shared Mutex))
    {
        version (Windows)
        {
            InitializeCriticalSection(cast(CRITICAL_SECTION*)&m_hndl);
        }
        else version (Posix)
        {
            import core.internal.abort : abort;
            pthread_mutexattr_t attr = void;

            !pthread_mutexattr_init(&attr) ||
                abort("Unable to initialize mutex");

            scope (exit) pthread_mutexattr_destroy(&attr);

            !pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE) ||
                abort("Unable to initialize mutex");

            !pthread_mutex_init(cast(pthread_mutex_t*)&m_hndl, &attr) ||
                abort("Unable to initialize mutex");
        }

        m_proxy.link = this;
        this.__monitor = cast(void*)&m_proxy;
    }


    /**
     * Initializes a mutex object and sets it as the monitor for o.
     *
     * In:
     *  o must not already have a monitor.
     */
    this(Object o) @trusted nothrow @nogc
    {
        this(o, true);
    }

    /// ditto
    this(Object o) shared @trusted nothrow @nogc
    {
        this(o, true);
    }

    // Undocumented, useful only in Mutex.this(Object).
    private this(this Q)(Object o, bool _unused_) @trusted nothrow @nogc
        if (is(Q == Mutex) || is(Q == shared Mutex))
    in
    {
        assert(o.__monitor is null,
            "The provided object has a monitor already set!");
    }
    body
    {
        this();
        o.__monitor = cast(void*)&m_proxy;
    }


    ~this() @trusted nothrow @nogc
    {
        version (Windows)
        {
            DeleteCriticalSection(&m_hndl);
        }
        else version (Posix)
        {
            import core.internal.abort : abort;
            !pthread_mutex_destroy(&m_hndl) ||
                abort("Unable to destroy mutex");
        }
        this.__monitor = null;
    }


    ////////////////////////////////////////////////////////////////////////////
    // General Actions
    ////////////////////////////////////////////////////////////////////////////


    /**
     * If this lock is not already held by the caller, the lock is acquired,
     * then the internal counter is incremented by one.
     *
     * Note:
     *    `Mutex.lock` does not throw, but a class derived from Mutex can throw.
     *    Use `lock_nothrow` in `nothrow @nogc` code.
     */
    @trusted void lock()
    {
        lock_nothrow();
    }

    /// ditto
    @trusted void lock() shared
    {
        lock_nothrow();
    }

    /// ditto
    final void lock_nothrow(this Q)() nothrow @trusted @nogc
        if (is(Q == Mutex) || is(Q == shared Mutex))
    {
        version (Windows)
        {
            EnterCriticalSection(&m_hndl);
        }
        else version (Posix)
        {
            if (pthread_mutex_lock(&m_hndl) == 0)
                return;

            SyncError syncErr = cast(SyncError) cast(void*) typeid(SyncError).initializer;
            syncErr.msg = "Unable to lock mutex.";
            throw syncErr;
        }
    }

    /**
     * Decrements the internal lock count by one.  If this brings the count to
     * zero, the lock is released.
     *
     * Note:
     *    `Mutex.unlock` does not throw, but a class derived from Mutex can throw.
     *    Use `unlock_nothrow` in `nothrow @nogc` code.
     */
    @trusted void unlock()
    {
        unlock_nothrow();
    }

    /// ditto
    @trusted void unlock() shared
    {
        unlock_nothrow();
    }

    /// ditto
    final void unlock_nothrow(this Q)() nothrow @trusted @nogc
        if (is(Q == Mutex) || is(Q == shared Mutex))
    {
        version (Windows)
        {
            LeaveCriticalSection(&m_hndl);
        }
        else version (Posix)
        {
            if (pthread_mutex_unlock(&m_hndl) == 0)
                return;

            SyncError syncErr = cast(SyncError) cast(void*) typeid(SyncError).initializer;
            syncErr.msg = "Unable to unlock mutex.";
            throw syncErr;
        }
    }

    /**
     * If the lock is held by another caller, the method returns.  Otherwise,
     * the lock is acquired if it is not already held, and then the internal
     * counter is incremented by one.
     *
     * Returns:
     *  true if the lock was acquired and false if not.
     *
     * Note:
     *    `Mutex.tryLock` does not throw, but a class derived from Mutex can throw.
     *    Use `tryLock_nothrow` in `nothrow @nogc` code.
     */
    bool tryLock() @trusted
    {
        return tryLock_nothrow();
    }

    /// ditto
    bool tryLock() shared @trusted
    {
        return tryLock_nothrow();
    }

    /// ditto
    final bool tryLock_nothrow(this Q)() nothrow @trusted @nogc
        if (is(Q == Mutex) || is(Q == shared Mutex))
    {
        version (Windows)
        {
            return TryEnterCriticalSection(&m_hndl) != 0;
        }
        else version (Posix)
        {
            return pthread_mutex_trylock(&m_hndl) == 0;
        }
    }


private:
    version (Windows)
    {
        CRITICAL_SECTION    m_hndl;
    }
    else version (Posix)
    {
        pthread_mutex_t     m_hndl;
    }

    struct MonitorProxy
    {
        Object.Monitor link;
    }

    MonitorProxy            m_proxy;


package:
    version (Posix)
    {
        pthread_mutex_t* handleAddr()
        {
            return &m_hndl;
        }
    }
}


////////////////////////////////////////////////////////////////////////////////
// Unit Tests
////////////////////////////////////////////////////////////////////////////////


version (unittest)
{
    private import core.thread;


    unittest
    {
        auto mutex      = new Mutex;
        int  numThreads = 10;
        int  numTries   = 1000;
        int  lockCount  = 0;

        void testFn()
        {
            for (int i = 0; i < numTries; ++i)
            {
                synchronized (mutex)
                {
                    ++lockCount;
                }
            }
        }

        auto group = new ThreadGroup;

        for (int i = 0; i < numThreads; ++i)
            group.create(&testFn);

        group.joinAll();
        assert(lockCount == numThreads * numTries);
    }
}
