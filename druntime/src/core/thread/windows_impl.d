/**
 * The windows_impl module provides low-level Windows code
 * for thread creation and management.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly, Walter Bright, Alex Rønne Petersen, Martin Nowak
 * Source:    $(DRUNTIMESRC core/thread/windows_impl.d)
 */

module core.thread.windows_impl;

import core.atomic;
import core.exception : onOutOfMemoryError;
import core.internal.traits : externDFunc;
import core.thread.osthread;
import core.thread.threadbase;
import core.time;

version (Windows):

version (all)
{
    import core.stdc.stdint : uintptr_t; // for _beginthreadex decl below
    import core.stdc.stdlib : free, malloc, realloc;
    import core.sys.windows.basetsd /+: HANDLE+/;
    import core.sys.windows.threadaux /+: getThreadStackBottom, impersonate_thread, OpenThreadHandle+/;
    import core.sys.windows.winbase /+: CloseHandle, CREATE_SUSPENDED, DuplicateHandle, GetCurrentThread,
        GetCurrentThreadId, GetCurrentProcess, GetExitCodeThread, GetSystemInfo, GetThreadContext,
        GetThreadPriority, INFINITE, ResumeThread, SetThreadPriority, Sleep,  STILL_ACTIVE,
        SuspendThread, SwitchToThread, SYSTEM_INFO, THREAD_PRIORITY_IDLE, THREAD_PRIORITY_NORMAL,
        THREAD_PRIORITY_TIME_CRITICAL, WAIT_OBJECT_0, WaitForSingleObject+/;
    import core.sys.windows.windef /+: TRUE+/;
    import core.sys.windows.winnt /+: CONTEXT, CONTEXT_CONTROL, CONTEXT_INTEGER+/;

    private extern (Windows) alias btex_fptr = uint function(void*);
    private extern (C) uintptr_t _beginthreadex(void*, uint, btex_fptr, void*, uint, uint*) nothrow @nogc;
}

version (GNU)
{
    import gcc.builtins;
}

version (CoreDdoc) {} else
class Thread : ThreadBase
{
    package HANDLE m_hndl;
    alias TLSKey = uint;

    this( void function() fn, size_t sz = 0 ) @safe pure nothrow @nogc
    {
        super(fn, sz);
    }

    this( void delegate() dg, size_t sz = 0 ) @safe pure nothrow @nogc
    {
        super(dg, sz);
    }

    package this( size_t sz = 0 ) @safe pure nothrow @nogc
    {
        super(sz);
    }

    ~this() nothrow @nogc
    {
        if (super.destructBeforeDtor())
            return;

        m_addr = m_addr.init;
        CloseHandle( m_hndl );
        m_hndl = m_hndl.init;
    }

    static Thread getThis() @safe nothrow @nogc
    {
        return ThreadBase.getThis().toThread;
    }

    version (all)
    {
        version (X86)
        {
            uint[8]         m_reg; // edi,esi,ebp,esp,ebx,edx,ecx,eax
        }
        else version (X86_64)
        {
            ulong[16]       m_reg; // rdi,rsi,rbp,rsp,rbx,rdx,rcx,rax
                                   // r8,r9,r10,r11,r12,r13,r14,r15
        }
        else
        {
            static assert(false, "Architecture not supported." );
        }
    }

    override final void[] savedRegisters() nothrow @nogc
    {
        return m_reg;
    }

    final Thread start() nothrow
    in
    {
        assert( !next && !prev );
    }
    do
    {
        auto wasThreaded  = multiThreadedFlag;
        multiThreadedFlag = true;
        scope( failure )
        {
            if ( !wasThreaded )
                multiThreadedFlag = false;
        }

        version (all)
        {
            // NOTE: If a thread is just executing DllMain()
            //       while another thread is started here, it holds an OS internal
            //       lock that serializes DllMain with CreateThread. As the code
            //       might request a synchronization on slock (e.g. in thread_findByAddr()),
            //       we cannot hold that lock while creating the thread without
            //       creating a deadlock
            //
            // Solution: Create the thread in suspended state and then
            //       add and resume it with slock acquired
            assert(m_sz <= uint.max, "m_sz must be less than or equal to uint.max");
            m_hndl = cast(HANDLE) _beginthreadex( null, cast(uint) m_sz, &thread_entryPoint, cast(void*) this, CREATE_SUSPENDED, &m_addr );
            if ( cast(size_t) m_hndl == 0 )
                onThreadError( "Error creating thread" );
        }

        slock.lock_nothrow();
        scope(exit) slock.unlock_nothrow();
        {
            incrementAboutToStart(this);

            if ( ResumeThread( m_hndl ) == -1 )
                onThreadError( "Error resuming thread" );

            return this;
        }
    }

    override final Throwable join( bool rethrow = true )
    {
        if ( m_addr != m_addr.init && WaitForSingleObject( m_hndl, INFINITE ) != WAIT_OBJECT_0 )
            throw new ThreadException( "Unable to join thread" );
        // NOTE: m_addr must be cleared before m_hndl is closed to avoid
        //       a race condition with isRunning. The operation is done
        //       with atomicStore to prevent compiler reordering.
        atomicStore!(MemoryOrder.raw)(*cast(shared)&m_addr, m_addr.init);
        CloseHandle( m_hndl );
        m_hndl = m_hndl.init;

        return super.join(rethrow);
    }

    version (all)
    {
        @property static int PRIORITY_MIN() @nogc nothrow pure @safe
        {
            return THREAD_PRIORITY_IDLE;
        }

        @property static const(int) PRIORITY_MAX() @nogc nothrow pure @safe
        {
            return THREAD_PRIORITY_TIME_CRITICAL;
        }

        @property static int PRIORITY_DEFAULT() @nogc nothrow pure @safe
        {
            return THREAD_PRIORITY_NORMAL;
        }
    }

    final @property int priority()
    {
        return GetThreadPriority( m_hndl );
    }

    final @property void priority( int val )
    in
    {
        assert(val >= PRIORITY_MIN);
        assert(val <= PRIORITY_MAX);
    }
    do
    {
        if ( !SetThreadPriority( m_hndl, val ) )
            throw new ThreadException( "Unable to set thread priority" );
    }

    override final @property bool isRunning() nothrow @nogc
    {
        if (!super.isRunning())
            return false;

        uint ecode = 0;
        GetExitCodeThread( m_hndl, &ecode );
        return ecode == STILL_ACTIVE;
    }

    static void sleep( Duration val ) @nogc nothrow @trusted
    in
    {
        assert( !val.isNegative );
    }
    do
    {
        version (all)
        {
            auto maxSleepMillis = dur!("msecs")( uint.max - 1 );

            // avoid a non-zero time to be round down to 0
            if ( val > dur!"msecs"( 0 ) && val < dur!"msecs"( 1 ) )
                val = dur!"msecs"( 1 );

            // NOTE: In instances where all other threads in the process have a
            //       lower priority than the current thread, the current thread
            //       will not yield with a sleep time of zero.  However, unlike
            //       yield(), the user is not asking for a yield to occur but
            //       only for execution to suspend for the requested interval.
            //       Therefore, expected performance may not be met if a yield
            //       is forced upon the user.
            while ( val > maxSleepMillis )
            {
                Sleep( cast(uint)
                       maxSleepMillis.total!"msecs" );
                val -= maxSleepMillis;
            }
            Sleep( cast(uint) val.total!"msecs" );
        }
    }

    static void yield() @nogc nothrow
    {
        SwitchToThread();
    }
}
