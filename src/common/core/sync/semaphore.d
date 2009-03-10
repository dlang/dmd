/**
 * The semaphore module provides a general use semaphore for synchronization.
 *
 * Copyright: Copyright (C) 2005-2009 Sean Kelly.  All rights reserved.
 * License:   BSD Style, see LICENSE
 * Authors:   Sean Kelly
 */
module core.sync.semaphore;


public import core.sync.exception;

version( Win32 )
{
    private import core.sys.windows.windows;
}
else version( OSX )
{
    private import core.sync.config;
    private import core.stdc.errno;
    private import core.sys.posix.time;
    private import core.sys.osx.mach.semaphore;
}
else version( Posix )
{
    private import core.sync.config;
    private import core.stdc.errno;
    private import core.sys.posix.pthread;
    private import core.sys.posix.semaphore;
}


////////////////////////////////////////////////////////////////////////////////
// Semaphore
//
// void wait();
// void notify();
// bool tryWait();
////////////////////////////////////////////////////////////////////////////////


/**
 * This class represents a general counting semaphore as concieved by Edsger
 * Dijkstra.  As per Mesa type monitors however, "signal" has been replaced
 * with "notify" to indicate that control is not transferred to the waiter when
 * a notification is sent.
 */
class Semaphore
{
    ////////////////////////////////////////////////////////////////////////////
    // Initialization
    ////////////////////////////////////////////////////////////////////////////


    /**
     * Initializes a semaphore object with the specified initial count.
     *
     * Params:
     *  count = The initial count for the semaphore.
     *
     * Throws:
     *  SyncException on error.
     */
    this( uint count = 0 )
    {
        version( Win32 )
        {
            m_hndl = CreateSemaphoreA( null, count, int.max, null );
            if( m_hndl == m_hndl.init )
                throw new SyncException( "Unable to create semaphore" );
        }
        else version( OSX )
        {
            auto rc = semaphore_create( mach_task_self(), &m_hndl, SYNC_POLICY_FIFO, count );
            if( rc )
                throw new SyncException( "Unable to create semaphore" );
        }
        else version( Posix )
        {
            int rc = sem_init( &m_hndl, 0, count );
            if( rc )
                throw new SyncException( "Unable to create semaphore" );
        }
    }


    ~this()
    {
        version( Win32 )
        {
            BOOL rc = CloseHandle( m_hndl );
            assert( rc, "Unable to destroy semaphore" );
        }
        else version( OSX )
        {
            auto rc = semaphore_destroy( mach_task_self(), m_hndl );
            assert( !rc, "Unable to destroy semaphore" );
        }
        else version( Posix )
        {
            int rc = sem_destroy( &m_hndl );
            assert( !rc, "Unable to destroy semaphore" );
        }
    }


    ////////////////////////////////////////////////////////////////////////////
    // General Actions
    ////////////////////////////////////////////////////////////////////////////


    /**
     * Wait until the current count is above zero, then atomically decrement
     * the count by one and return.
     *
     * Throws:
     *  SyncException on error.
     */
    void wait()
    {
        version( Win32 )
        {
            DWORD rc = WaitForSingleObject( m_hndl, INFINITE );
            if( rc != WAIT_OBJECT_0 )
                throw new SyncException( "Unable to wait for semaphore" );
        }
        else version( OSX )
        {
            while( true )
            {
                auto rc = semaphore_wait( m_hndl );
                if( !rc )
                    return;
                if( rc == KERN_ABORTED && errno == EINTR )
                    continue;
                throw new SyncException( "Unable to wait for semaphore" );
            }
        }
        else version( Posix )
        {
            while( true )
            {
                if( !sem_wait( &m_hndl ) )
                    return;
                if( errno != EINTR )
                    throw new SyncException( "Unable to wait for semaphore" );
            }
        }
    }


    /**
     * Suspends the calling thread until the current count moves above zero or
     * until the supplied time period has elapsed.  If the count moves above
     * zero in this interval, then atomically decrement the count by one and
     * return true.  Otherwise, return false.
     *
     *
     * Params:
     *  period = The time to wait, in 100 nanosecond intervals.  This value may
     *           be adjusted to equal to the maximum wait period supported by
     *           the target platform if it is too large.
     *
     * In:
     *  period must be non-negative.
     *
     * Throws:
     *  SyncException on error.
     *
     * Returns:
     *  true if notified before the timeout and false if not.
     */
    bool wait( long period )
    in
    {
        assert( period >= 0 );
    }
    body
    {
        version( Win32 )
        {
            enum : uint
            {
                TICKS_PER_MILLI = 10_000,
                MAX_WAIT_MILLIS = uint.max - 1
            }

            period /= TICKS_PER_MILLI;
            if( period > MAX_WAIT_MILLIS )
                period = MAX_WAIT_MILLIS;
            switch( WaitForSingleObject( m_hndl, cast(uint) period ) )
            {
            case WAIT_OBJECT_0:
                return true;
            case WAIT_TIMEOUT:
                return false;
            default:
                throw new SyncException( "Unable to wait for semaphore" );
            }
        }
        else version( OSX )
        {            
            mach_timespec_t t = void;
            (cast(byte*) &t)[0 .. t.sizeof] = 0;

            if( period != 0 )
            {
                enum : uint
                {
                    NANOS_PER_TICK   = 100,
                    TICKS_PER_SECOND = 10_000_000,
                    NANOS_PER_SECOND = NANOS_PER_TICK * TICKS_PER_SECOND,
                }

                if( t.tv_sec.max - t.tv_sec < period / TICKS_PER_SECOND )
                {
                    t.tv_sec  = t.tv_sec.max;
                    t.tv_nsec = 0;
                }
                else
                {
                    t.tv_sec += cast(typeof(t.tv_sec)) (period / TICKS_PER_SECOND);
                    long ns = (period % TICKS_PER_SECOND) * NANOS_PER_TICK;
                    if( NANOS_PER_SECOND - t.tv_nsec > ns )
                        t.tv_nsec = cast(typeof(t.tv_nsec)) ns;
                    else
                    {
                        t.tv_sec  += 1;
                        t.tv_nsec += ns - NANOS_PER_SECOND;
                    }
                }
            }
            while( true )
            {
                auto rc = semaphore_timedwait( m_hndl, t );
                if( !rc )
                    return true;
                if( rc == KERN_OPERATION_TIMED_OUT )
                    return false;
                if( rc != KERN_ABORTED || errno != EINTR )
                    throw new SyncException( "Unable to wait for semaphore" );
            }
            // -w trip
            return false;
        }
        else version( Posix )
        {
            timespec t = void;
            mktspec( t, period );

            while( true )
            {
                if( !sem_timedwait( &m_hndl, &t ) )
                    return true;
                if( errno == ETIMEDOUT )
                    return false;
                if( errno != EINTR )
                    throw new SyncException( "Unable to wait for semaphore" );
            }
            // -w trip
            return false;
        }
    }


    /**
     * Atomically increment the current count by one.  This will notify one
     * waiter, if there are any in the queue.
     *
     * Throws:
     *  SyncException on error.
     */
    void notify()
    {
        version( Win32 )
        {
            if( !ReleaseSemaphore( m_hndl, 1, null ) )
                throw new SyncException( "Unable to notify semaphore" );
        }
        else version( OSX )
        {
            auto rc = semaphore_signal( m_hndl );
            if( rc )
                throw new SyncException( "Unable to notify semaphore" );
        }
        else version( Posix )
        {
            int rc = sem_post( &m_hndl );
            if( rc )
                throw new SyncException( "Unable to notify semaphore" );
        }
    }


    /**
     * If the current count is equal to zero, return.  Otherwise, atomically
     * decrement the count by one and return true.
     *
     * Throws:
     *  SyncException on error.
     *
     * Returns:
     *  true if the count was above zero and false if not.
     */
    bool tryWait()
    {
        version( Win32 )
        {
            switch( WaitForSingleObject( m_hndl, 0 ) )
            {
            case WAIT_OBJECT_0:
                return true;
            case WAIT_TIMEOUT:
                return false;
            default:
                throw new SyncException( "Unable to wait for semaphore" );
            }
        }
        else version( OSX )
        {
            return wait( 0 );
        }
        else version( Posix )
        {
            while( true )
            {
                if( !sem_trywait( &m_hndl ) )
                    return true;
                if( errno == EAGAIN )
                    return false;
                if( errno != EINTR )
                    throw new SyncException( "Unable to wait for semaphore" );
            }
            // -w trip
            return false;
        }
    }


private:
    version( Win32 )
    {
        HANDLE  m_hndl;
    }
    else version( OSX )
    {
        semaphore_t m_hndl;
    }
    else version( Posix )
    {
        sem_t   m_hndl;
    }
}


////////////////////////////////////////////////////////////////////////////////
// Unit Tests
////////////////////////////////////////////////////////////////////////////////


version( unittest )
{
    private import core.thread;


    void testWait()
    {
        auto semaphore    = new Semaphore;
        int  numToProduce = 10;
        bool allProduced  = false;
        auto synProduced  = new Object;
        int  numConsumed  = 0;
        auto synConsumed  = new Object;
        int  numConsumers = 10;
        int  numComplete  = 0;
        auto synComplete  = new Object;

        void consumer()
        {
            while( true )
            {
                semaphore.wait();

                synchronized( synProduced )
                {
                    if( allProduced )
                        break;
                }

                synchronized( synConsumed )
                {
                    ++numConsumed;
                }
            }

            synchronized( synComplete )
            {
                ++numComplete;
            }
        }

        void producer()
        {
            assert( !semaphore.tryWait() );

            for( int i = 0; i < numToProduce; ++i )
            {
                semaphore.notify();
                Thread.yield();
            }
            Thread.sleep( 10_000_000 ); // 1s
            synchronized( synProduced )
            {
                allProduced = true;
            }

            for( int i = 0; i < numConsumers; ++i )
            {
                semaphore.notify();
                Thread.yield();
            }

            for( int i = numConsumers * 10000; i > 0; --i )
            {
                synchronized( synComplete )
                {
                    if( numComplete == numConsumers )
                        break;
                }
                Thread.yield();
            }

            synchronized( synComplete )
            {
                assert( numComplete == numConsumers );
            }

            synchronized( synConsumed )
            {
                assert( numConsumed == numToProduce );
            }

            assert( !semaphore.tryWait() );
            semaphore.notify();
            assert( semaphore.tryWait() );
            assert( !semaphore.tryWait() );
        }

        auto group = new ThreadGroup;

        for( int i = 0; i < numConsumers; ++i )
            group.create( &consumer );
        group.create( &producer );
        group.joinAll();
    }


    void testWaitTimeout()
    {
        auto synReady   = new Object;
        auto semReady   = new Semaphore;
        bool waiting    = false;
        bool alertedOne = true;
        bool alertedTwo = true;

        void waiter()
        {
            synchronized( synReady )
            {
                waiting    = true;
            }
            alertedOne = semReady.wait( 10_000_000 ); // 100ms
            alertedTwo = semReady.wait( 10_000_000 ); // 100ms
        }

        auto thread = new Thread( &waiter );
        thread.start();

        while( true )
        {
            synchronized( synReady )
            {
                if( waiting )
                {
                    semReady.notify();
                    break;
                }
            }
            Thread.yield();
        }
        thread.join();
        assert( waiting && alertedOne && !alertedTwo );
    }


    unittest
    {
        testWait();
        testWaitTimeout();
    }
}
