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
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sync.mutex;


public import core.sync.exception;

version( Win32 )
{
    private import core.sys.windows.windows;
}
else version( Posix )
{
    private import core.sys.posix.pthread;
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
     * Throws:
     *  SyncException on error.
     */
    this()
    {
        version( Win32 )
        {
            InitializeCriticalSection( &m_hndl );
        }
        else version( Posix )
        {
            pthread_mutexattr_t attr = void;

            if( pthread_mutexattr_init( &attr ) )
                throw new SyncException( "Unable to initialize mutex" );
            scope(exit) pthread_mutexattr_destroy( &attr );

            if( pthread_mutexattr_settype( &attr, PTHREAD_MUTEX_RECURSIVE ) )
                throw new SyncException( "Unable to initialize mutex" );

            if( pthread_mutex_init( &m_hndl, &attr ) )
                throw new SyncException( "Unable to initialize mutex" );
        }
        m_proxy.link = this;
        this.__monitor = &m_proxy;
    }


    /**
     * Initializes a mutex object and sets it as the monitor for o.
     *
     * In:
     *  o must not already have a monitor.
     */
    this( Object o )
    in
    {
        assert( o.__monitor is null );
    }
    body
    {
        this();
        o.__monitor = &m_proxy;
    }


    ~this()
    {
        version( Win32 )
        {
            DeleteCriticalSection( &m_hndl );
        }
        else version( Posix )
        {
            int rc = pthread_mutex_destroy( &m_hndl );
            assert( !rc, "Unable to destroy mutex" );
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
     * Throws:
     *  SyncException on error.
     */
    void lock()
    {
        version( Win32 )
        {
            EnterCriticalSection( &m_hndl );
        }
        else version( Posix )
        {
            int rc = pthread_mutex_lock( &m_hndl );
            if( rc )
                throw new SyncException( "Unable to lock mutex" );
        }
    }


    /**
     * Decrements the internal lock count by one.  If this brings the count to
     * zero, the lock is released.
     *
     * Throws:
     *  SyncException on error.
     */
    void unlock()
    {
        version( Win32 )
        {
            LeaveCriticalSection( &m_hndl );
        }
        else version( Posix )
        {
            int rc = pthread_mutex_unlock( &m_hndl );
            if( rc )
                throw new SyncException( "Unable to unlock mutex" );
        }
    }


    /**
     * If the lock is held by another caller, the method returns.  Otherwise,
     * the lock is acquired if it is not already held, and then the internal
     * counter is incremented by one.
     *
     * Throws:
     *  SyncException on error.
     *
     * Returns:
     *  true if the lock was acquired and false if not.
     */
    bool tryLock()
    {
        version( Win32 )
        {
            return TryEnterCriticalSection( &m_hndl ) != 0;
        }
        else version( Posix )
        {
            return pthread_mutex_trylock( &m_hndl ) == 0;
        }
    }


private:
    version( Win32 )
    {
        CRITICAL_SECTION    m_hndl;
    }
    else version( Posix )
    {
        pthread_mutex_t     m_hndl;
    }

    struct MonitorProxy
    {
        Object.Monitor link;
    }

    MonitorProxy            m_proxy;


package:
    version( Posix )
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


version( unittest )
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
            for( int i = 0; i < numTries; ++i )
            {
                synchronized( mutex )
                {
                    ++lockCount;
                }
            }
        }

        auto group = new ThreadGroup;

        for( int i = 0; i < numThreads; ++i )
            group.create( &testFn );

        group.joinAll();
        assert( lockCount == numThreads * numTries );
    }
}
