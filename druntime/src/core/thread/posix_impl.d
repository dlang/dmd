/**
 * The posix_impl module provides low-level Posix code
 * for thread creation and management.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly, Walter Bright, Alex Rønne Petersen, Martin Nowak
 * Source:    $(DRUNTIMESRC core/thread/posix_impl.d)
 */

module core.thread.posix_impl;

import core.atomic;
import core.exception : onOutOfMemoryError;
import core.internal.traits : externDFunc;
import core.thread.osthread;
import core.thread.threadbase;
import core.thread.types : ThreadID, ThreadDescr, ll_ThreadData;
import core.time;

version (Posix):

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (all)
{
    static import core.sys.posix.pthread;
    import core.stdc.errno : EINTR, errno;

    version (CRuntime_WASI)
        import core.sys.posix.pthread : pthread_attr_destroy, pthread_attr_getstack,
            pthread_attr_init, pthread_attr_setstacksize, pthread_create, pthread_detach,
            pthread_join, pthread_self, sched_yield;
    else
    {
        static import core.sys.posix.signal;

        import core.sys.posix.pthread : pthread_atfork, pthread_attr_destroy, pthread_attr_getstack,
            pthread_attr_init, pthread_attr_setstacksize, pthread_create, pthread_detach, pthread_getschedparam,
            pthread_join, pthread_self, pthread_setschedparam, sched_get_priority_max, sched_get_priority_min,
            sched_param, sched_yield;

        import core.sys.posix.semaphore : sem_init, sem_post, sem_t, sem_wait;

        import core.sys.posix.signal : pthread_kill, sigaction, sigaction_t, sigdelset, sigfillset, sigset_t, sigsuspend,
            SIGUSR1, stack_t;
    }

    import core.sys.posix.stdlib : free, malloc, realloc;
    import core.sys.posix.sys.types : pthread_attr_t, pthread_key_t, pthread_t;
    import core.sys.posix.time : nanosleep, timespec;

    version (Darwin)
    {
        // Use macOS threads for suspend/resume
        import core.sys.darwin.mach.kern_return : KERN_SUCCESS;
        import core.sys.darwin.mach.thread_act : mach_msg_type_number_t,
            thread_get_state, thread_resume, thread_suspend;
        import core.sys.darwin.pthread : pthread_mach_thread_np;
        version (X86)
        {
            import core.sys.darwin.mach.thread_act :
             x86_THREAD_STATE32, x86_THREAD_STATE32_COUNT, x86_thread_state32_t;
        }
        else version (X86_64)
        {
            import core.sys.darwin.mach.thread_act :
             x86_THREAD_STATE64, x86_THREAD_STATE64_COUNT, x86_thread_state64_t;
        }
        else version (AArch64)
        {
            import core.sys.darwin.mach.thread_act :
             ARM_THREAD_STATE64, ARM_THREAD_STATE64_COUNT, arm_thread_state64_t;
        }
        else version (PPC)
        {
            import core.sys.darwin.mach.thread_act :
             PPC_THREAD_STATE, PPC_THREAD_STATE_COUNT, ppc_thread_state_t;
        }
        else version (PPC64)
        {
            import core.sys.darwin.mach.thread_act :
             PPC_THREAD_STATE64, PPC_THREAD_STATE64_COUNT, ppc_thread_state64_t;
        }
    }
    else version (Solaris)
    {
        // Use Solaris threads for suspend/resume
        import core.sys.posix.sys.wait : idtype_t;
        import core.sys.solaris.sys.priocntl : PC_CLNULL, PC_GETCLINFO, PC_GETPARMS, PC_SETPARMS, pcinfo_t, pcparms_t, priocntl;
        import core.sys.solaris.sys.types : P_MYID, pri_t;
        import core.sys.solaris.thread : thr_stksegment, thr_suspend, thr_continue;
        import core.sys.solaris.sys.procfs : PR_STOPPED, lwpstatus_t;
    }
    else
    {
        // Use POSIX threads for suspend/resume
    }
}

version (GNU)
{
    import gcc.builtins;
}

package enum isSingleThreaded = false;

version (CoreDdoc) {} else
class Thread : ThreadBase
{
    package shared bool     m_isRunning;

    version (Solaris)
    {
        private __gshared bool m_isRTClass;
    }

    alias TLSKey = pthread_key_t;

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

        version (all)
        {
            if (m_tdescr.tid != m_tdescr.tid.init)
                pthread_detach( m_tdescr.tid );
            m_tdescr.tid = m_tdescr.tid.init;
            version (Darwin)
            {
                m_tdescr.tmach = m_tdescr.tmach.init;
            }
        }
    }

    static Thread getThis() @safe nothrow @nogc
    {
        return ThreadBase.getThis().toThread;
    }

    version (Darwin)
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
        else version (AArch64)
        {
            ulong[33]       m_reg; // x0-x31, pc
        }
        else version (ARM)
        {
            uint[16]        m_reg; // r0-r15
        }
        else version (PPC)
        {
            // Make the assumption that we only care about non-fp and non-vr regs.
            // ??? : it seems plausible that a valid address can be copied into a VR.
            uint[32]        m_reg; // r0-31
        }
        else version (PPC64)
        {
            // As above.
            ulong[32]       m_reg; // r0-31
        }
        else
        {
            static assert(false, "Architecture not supported." );
        }
    }
    else version (Solaris)
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
        else version (SPARC)
        {
            int[33]         m_reg; // g0-7, o0-7, l0-7, i0-7, pc
        }
        else version (SPARC64)
        {
            long[33]        m_reg; // g0-7, o0-7, l0-7, i0-7, pc
        }
        else
        {
            static assert(false, "Architecture not supported." );
        }
    }

    override final void[] savedRegisters() nothrow @nogc
    {
        version (Darwin)
        {
            return m_reg;
        }
        else version (Solaris)
        {
            return m_reg;
        }
        else
        {
            return null;
        }
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
            size_t stksz = adjustStackSize( m_sz );

            pthread_attr_t  attr;

            if ( pthread_attr_init( &attr ) )
                onThreadError( "Error initializing thread attributes" );
            if ( stksz && pthread_attr_setstacksize( &attr, stksz ) )
                onThreadError( "Error initializing thread stack size" );
        }

        slock.lock_nothrow();
        scope(exit) slock.unlock_nothrow();
        {
            incrementAboutToStart(this);
            scope(failure) decrementAboutToStart(this);

            version (all)
            {
                // NOTE: This is also set to true by thread_entryPoint, but set it
                //       here as well so the calling thread will see the isRunning
                //       state immediately.
                atomicStore!(MemoryOrder.raw)(m_isRunning, true);
                scope( failure ) atomicStore!(MemoryOrder.raw)(m_isRunning, false);

                version (Shared)
                {
                    auto libs = externDFunc!("rt.sections_elf_shared.pinLoadedLibraries",
                                             void* function() @nogc nothrow)();

                    auto ps = cast(void**).malloc(2 * size_t.sizeof);
                    if (ps is null) onOutOfMemoryError();
                    ps[0] = cast(void*)this;
                    ps[1] = cast(void*)libs;
                    if ( pthread_create( &m_tdescr.tid, &attr, &thread_entryPoint, ps ) != 0 )
                    {
                        externDFunc!("rt.sections_elf_shared.unpinLoadedLibraries",
                                     void function(void*) @nogc nothrow)(libs);
                        .free(ps);
                        onThreadError( "Error creating thread" );
                    }
                }
                else
                {
                    if ( pthread_create( &m_tdescr.tid, &attr, &thread_entryPoint, cast(void*) this ) != 0 )
                        onThreadError( "Error creating thread" );
                }
                if ( pthread_attr_destroy( &attr ) != 0 )
                    onThreadError( "Error destroying thread attributes" );

                version (Darwin)
                {
                    m_tdescr.tmach = pthread_mach_thread_np( m_tdescr.tid );
                    if ( m_tdescr.tmach == m_tdescr.tmach.init )
                        onThreadError( "Error creating thread" );
                }
            }

            return this;
        }
    }

    override final Throwable join( bool rethrow = true )
    {
        if ( m_tdescr.tid != m_tdescr.tid.init && pthread_join( m_tdescr.tid, null ) != 0 )
            throw new ThreadException( "Unable to join thread" );
        // NOTE: pthread_join acts as a substitute for pthread_detach,
        //       which is normally called by the dtor.  Setting tid
        //       to zero ensures that pthread_detach will not be called
        //       on object destruction.
        m_tdescr.tid = m_tdescr.tid.init;

        return super.join(rethrow);
    }

    version (CRuntime_WASI)
    {
        @property static int PRIORITY_MIN() @nogc nothrow pure @safe
        {
            return 0;
        }

        @property static const(int) PRIORITY_MAX() @nogc nothrow pure @safe
        {
            return 0;
        }

        @property static int PRIORITY_DEFAULT() @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    else version (all)
    {
        package struct Priority
        {
            int PRIORITY_MIN = int.min;
            int PRIORITY_DEFAULT = int.min;
            int PRIORITY_MAX = int.min;
        }

        /*
        Lazily loads one of the members stored in a hidden global variable of
        type `Priority`. Upon the first access of either member, the entire
        `Priority` structure is initialized. Multiple initializations from
        different threads calling this function are tolerated.

        `which` must be one of `PRIORITY_MIN`, `PRIORITY_DEFAULT`,
        `PRIORITY_MAX`.
        */
        private static shared Priority cache;
        private static int loadGlobal(string which)()
        {
            auto local = atomicLoad(mixin("cache." ~ which));
            if (local != local.min) return local;
            // There will be benign races
            auto loaded = loadPriorities;
            static foreach (i, _; loaded.tupleof)
                atomicStore(cache.tupleof[i], loaded.tupleof[i]);
            return atomicLoad(mixin("cache." ~ which));
        }

        /*
        Loads all priorities and returns them as a `Priority` structure. This
        function is thread-neutral.
        */
        private static Priority loadPriorities() @nogc nothrow @trusted
        {
            Priority result;
            version (Solaris)
            {
                pcparms_t pcParms;
                pcinfo_t pcInfo;

                pcParms.pc_cid = PC_CLNULL;
                if (priocntl(idtype_t.P_PID, P_MYID, PC_GETPARMS, &pcParms) == -1)
                    assert( 0, "Unable to get scheduling class" );

                pcInfo.pc_cid = pcParms.pc_cid;
                // PC_GETCLINFO ignores the first two args, use dummy values
                if (priocntl(idtype_t.P_PID, 0, PC_GETCLINFO, &pcInfo) == -1)
                    assert( 0, "Unable to get scheduling class info" );

                pri_t* clparms = cast(pri_t*)&pcParms.pc_clparms;
                pri_t* clinfo = cast(pri_t*)&pcInfo.pc_clinfo;

                result.PRIORITY_MAX = clparms[0];

                if (pcInfo.pc_clname == "RT")
                {
                    m_isRTClass = true;

                    // For RT class, just assume it can't be changed
                    result.PRIORITY_MIN = clparms[0];
                    result.PRIORITY_DEFAULT = clparms[0];
                }
                else
                {
                    m_isRTClass = false;

                    // For all other scheduling classes, there are
                    // two key values -- uprilim and maxupri.
                    // maxupri is the maximum possible priority defined
                    // for the scheduling class, and valid priorities
                    // range are in [-maxupri, maxupri].
                    //
                    // However, uprilim is an upper limit that the
                    // current thread can set for the current scheduling
                    // class, which can be less than maxupri.  As such,
                    // use this value for priorityMax since this is
                    // the effective maximum.

                    // maxupri
                    result.PRIORITY_MIN = -cast(int)(clinfo[0]);
                    // by definition
                    result.PRIORITY_DEFAULT = 0;
                }
            }
            else
            {
                int         policy;
                sched_param param;
                pthread_getschedparam( pthread_self(), &policy, &param ) == 0
                    || assert(0, "Internal error in pthread_getschedparam");

                result.PRIORITY_MIN = sched_get_priority_min( policy );
                result.PRIORITY_MIN != -1
                    || assert(0, "Internal error in sched_get_priority_min");
                result.PRIORITY_DEFAULT = param.sched_priority;
                result.PRIORITY_MAX = sched_get_priority_max( policy );
                result.PRIORITY_MAX != -1 ||
                    assert(0, "Internal error in sched_get_priority_max");
            }
            return result;
        }

        @property static int PRIORITY_MIN() @nogc nothrow pure @trusted
        {
            return (cast(int function() @nogc nothrow pure @safe)
                &loadGlobal!"PRIORITY_MIN")();
        }

        @property static const(int) PRIORITY_MAX() @nogc nothrow pure @trusted
        {
            return (cast(int function() @nogc nothrow pure @safe)
                &loadGlobal!"PRIORITY_MAX")();
        }

        @property static int PRIORITY_DEFAULT() @nogc nothrow pure @trusted
        {
            return (cast(int function() @nogc nothrow pure @safe)
                &loadGlobal!"PRIORITY_DEFAULT")();
        }
    }

    version (NetBSD)
    {
        //NetBSD does not support priority for default policy
        // and it is not possible change policy without root access
        int fakePriority = int.max;
    }

    final @property int priority()
    {
        version (NetBSD)
        {
           return fakePriority==int.max? PRIORITY_DEFAULT : fakePriority;
        }
        else version (CRuntime_WASI)
        {
            return PRIORITY_DEFAULT;
        }
        else
        {
            int         policy;
            sched_param param;

            if (auto err = pthread_getschedparam(m_tdescr.tid, &policy, &param))
            {
                // ignore error if thread is not running => Bugzilla 8960
                if (!atomicLoad(m_isRunning)) return PRIORITY_DEFAULT;
                throw new ThreadException("Unable to get thread priority");
            }
            return param.sched_priority;
        }
    }

    final @property void priority( int val )
    in
    {
        assert(val >= PRIORITY_MIN);
        assert(val <= PRIORITY_MAX);
    }
    do
    {
        version (Solaris)
        {
            // the pthread_setschedprio(3c) and pthread_setschedparam functions
            // are broken for the default (TS / time sharing) scheduling class.
            // instead, we use priocntl(2) which gives us the desired behavior.

            // We hardcode the min and max priorities to the current value
            // so this is a no-op for RT threads.
            if (m_isRTClass)
                return;

            pcparms_t   pcparm;

            pcparm.pc_cid = PC_CLNULL;
            if (priocntl(idtype_t.P_LWPID, P_MYID, PC_GETPARMS, &pcparm) == -1)
                throw new ThreadException( "Unable to get scheduling class" );

            pri_t* clparms = cast(pri_t*)&pcparm.pc_clparms;

            // clparms is filled in by the PC_GETPARMS call, only necessary
            // to adjust the element that contains the thread priority
            clparms[1] = cast(pri_t) val;

            if (priocntl(idtype_t.P_LWPID, P_MYID, PC_SETPARMS, &pcparm) == -1)
                throw new ThreadException( "Unable to set scheduling class" );
        }
        else version (NetBSD)
        {
           fakePriority = val;
        }
        else version (CRuntime_WASI)
        {
            // do nothing
        }
        else
        {
            static if (__traits(compiles, core.sys.posix.pthread.pthread_setschedprio))
            {
                import core.sys.posix.pthread : pthread_setschedprio;

                if (auto err = pthread_setschedprio(m_tdescr.tid, val))
                {
                    // ignore error if thread is not running => Bugzilla 8960
                    if (!atomicLoad(m_isRunning)) return;
                    throw new ThreadException("Unable to set thread priority");
                }
            }
            else
            {
                // NOTE: pthread_setschedprio is not implemented on Darwin, FreeBSD, OpenBSD,
                //       or DragonFlyBSD, so use the more complicated get/set sequence below.
                int         policy;
                sched_param param;

                if (auto err = pthread_getschedparam(m_tdescr.tid, &policy, &param))
                {
                    // ignore error if thread is not running => Bugzilla 8960
                    if (!atomicLoad(m_isRunning)) return;
                    throw new ThreadException("Unable to set thread priority");
                }
                param.sched_priority = val;
                if (auto err = pthread_setschedparam(m_tdescr.tid, policy, &param))
                {
                    // ignore error if thread is not running => Bugzilla 8960
                    if (!atomicLoad(m_isRunning)) return;
                    throw new ThreadException("Unable to set thread priority");
                }
            }
        }
    }

    override final @property bool isRunning() nothrow @nogc
    {
        if (!super.isRunning())
            return false;

        return atomicLoad(m_isRunning);
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
            timespec tin  = void;
            timespec tout = void;

            val.split!("seconds", "nsecs")(tin.tv_sec, tin.tv_nsec);
            if ( val.total!"seconds" > tin.tv_sec.max )
                tin.tv_sec  = tin.tv_sec.max;
            while ( true )
            {
                if ( !nanosleep( &tin, &tout ) )
                    return;
                if ( errno != EINTR )
                    assert(0, "Unable to sleep for the specified duration");
                tin = tout;
            }
        }
    }

    static void yield() @nogc nothrow
    {
        sched_yield();
    }

    package static ThreadDescr getCurrentThreadDescr() nothrow @nogc
    {
        version (Darwin)
        {
            auto tid = gettid();
            auto tmach = pthread_mach_thread_np(tid);
            assert(tmach != tmach.init);

            return ThreadDescr(tid: tid, tmach: tmach);
        }
        else
            return ThreadDescr(tid: gettid);
    }

    package static void afterDeploy() nothrow @nogc
    {
        version (Darwin)
        {
            // thread id different in forked child process
            static extern(C) void initChildAfterFork()
            {
                auto thisThread = Thread.getThis();
                if (!thisThread)
                {
                    // It is possible that runtime was not properly initialized in the current process or thread -
                    // it may happen after `fork` call when using a dynamically loaded shared library written in D from a multithreaded non-D program.
                    // In such case getThis will return null.
                    return;
                }
                thisThread.m_tdescr.tid = pthread_self();
                assert( thisThread.m_tdescr.tid != thisThread.m_tdescr.tid.init );
                thisThread.m_tdescr.tmach = pthread_mach_thread_np( thisThread.m_tdescr.tid );
                assert( thisThread.m_tdescr.tmach != thisThread.m_tdescr.tmach.init );
           }
            pthread_atfork(null, null, &initChildAfterFork);
        }
        else version (Solaris)
        {
        }
        else version (CRuntime_WASI)
        {
        }
        else
        {
            version (OpenBSD)
            {
                // OpenBSD does not support SIGRTMIN or SIGRTMAX
                // Use SIGUSR1 for SIGRTMIN, SIGUSR2 for SIGRTMIN + 1
                // And use 32 for SIGRTMAX (32 is the max signal number on OpenBSD)
                enum SIGRTMIN = SIGUSR1;
                enum SIGRTMAX = 32;
            }
            else version (Hurd)
            {
                // Hurd does not support SIGRTMIN or SIGRTMAX
                // Use SIGUSR1 for SIGRTMIN, SIGUSR2 for SIGRTMIN + 1
                // And use 32 for SIGRTMAX (32 is the max signal number on Hurd)
                enum SIGRTMIN = SIGUSR1;
                enum SIGRTMAX = 32;
            }
            else
            {
                import core.sys.posix.signal : SIGRTMAX, SIGRTMIN;
            }

            if ( suspendSignalNumber == 0 )
            {
                suspendSignalNumber = SIGRTMIN;
            }

            if ( resumeSignalNumber == 0 )
            {
                resumeSignalNumber = SIGRTMIN + 1;
                assert(resumeSignalNumber <= SIGRTMAX);
            }
            int         status;
            sigaction_t suspend = void;
            sigaction_t resume = void;

            // This is a quick way to zero-initialize the structs without using
            // memset or creating a link dependency on their static initializer.
            (cast(byte*) &suspend)[0 .. sigaction_t.sizeof] = 0;
            (cast(byte*)  &resume)[0 .. sigaction_t.sizeof] = 0;

            // NOTE: SA_RESTART indicates that system calls should restart if they
            //       are interrupted by a signal, but this is not available on all
            //       Posix systems, even those that support multithreading.
            static if (__traits(compiles, core.sys.posix.signal.SA_RESTART))
            {
                import core.sys.posix.signal : SA_RESTART;

                suspend.sa_flags = SA_RESTART;
            }

            suspend.sa_handler = &thread_suspendHandler;
            // NOTE: We want to ignore all signals while in this handler, so fill
            //       sa_mask to indicate this.
            status = sigfillset( &suspend.sa_mask );
            assert( status == 0 );

            // NOTE: Since resumeSignalNumber should only be issued for threads within the
            //       suspend handler, we don't want this signal to trigger a
            //       restart.
            resume.sa_flags   = 0;
            resume.sa_handler = &thread_resumeHandler;
            // NOTE: We want to ignore all signals while in this handler, so fill
            //       sa_mask to indicate this.
            status = sigfillset( &resume.sa_mask );
            assert( status == 0 );

            status = sigaction( suspendSignalNumber, &suspend, null );
            assert( status == 0 );

            status = sigaction( resumeSignalNumber, &resume, null );
            assert( status == 0 );

            status = sem_init( &suspendCount, 0, 0 );
            assert( status == 0 );
        }
    }
}

version (CoreDdoc) {} else
version (CRuntime_WASI) {} else
extern (C) void thread_setGCSignals(int suspendSignalNo, int resumeSignalNo) nothrow @nogc
in
{
    assert(suspendSignalNo != 0);
    assert(resumeSignalNo  != 0);
}
out
{
    assert(suspendSignalNumber != 0);
    assert(resumeSignalNumber  != 0);
}
do
{
    suspendSignalNumber = suspendSignalNo;
    resumeSignalNumber  = resumeSignalNo;
}

version (CoreDdoc) {} else
version (CRuntime_WASI) {} else
extern (C) void thread_getGCSignals(out int suspendSignalNo, out int resumeSignalNo) nothrow @nogc
in
{
    assert(suspendSignalNumber != 0);
    assert(resumeSignalNumber  != 0);
}
out
{
    assert(suspendSignalNo != 0);
    assert(resumeSignalNo  != 0);
}
do
{
    suspendSignalNo = suspendSignalNumber;
    resumeSignalNo  = resumeSignalNumber;
}

//TODO: private

version (CRuntime_WASI) {}
else
{
    package __gshared int suspendSignalNumber;
    package __gshared int resumeSignalNumber;
}

// Returns true on success
package bool suspendThreadImpl(Thread t) @nogc nothrow
{
    version (Darwin)
        return thread_suspend(t.m_tdescr.tmach) == KERN_SUCCESS;
    else version (Solaris)
        return thr_suspend(t.m_tdescr.tid) == 0;
    else version (CRuntime_WASI)
        return false;
    else
        return pthread_kill(t.m_tdescr.tid, suspendSignalNumber) == 0;
}

// Returns true on success
package bool resumeThreadImpl(Thread t) @nogc nothrow
{
    version (Darwin)
        return thread_resume(t.m_tdescr.tmach) == KERN_SUCCESS;
    else version (Solaris)
        return thr_continue(t.m_tdescr.tid) == 0;
    else version (CRuntime_WASI)
        return false;
    else
        return pthread_kill(t.m_tdescr.tid, resumeSignalNumber) == 0;
}

package void loadStackAndRegInfo(Thread t, const bool sameThread) nothrow @nogc
{
    version (Darwin)
    {
        version (X86)
        {
            x86_thread_state32_t    state = void;
            mach_msg_type_number_t  count = x86_THREAD_STATE32_COUNT;

            if ( thread_get_state( t.m_tdescr.tmach, x86_THREAD_STATE32, &state, &count ) != KERN_SUCCESS )
                onThreadError( "Unable to load thread state" );
            if ( !t.m_lock )
                t.m_curr.tstack = cast(void*) state.esp;
            // eax,ebx,ecx,edx,edi,esi,ebp,esp
            t.m_reg[0] = state.eax;
            t.m_reg[1] = state.ebx;
            t.m_reg[2] = state.ecx;
            t.m_reg[3] = state.edx;
            t.m_reg[4] = state.edi;
            t.m_reg[5] = state.esi;
            t.m_reg[6] = state.ebp;
            t.m_reg[7] = state.esp;
        }
        else version (X86_64)
        {
            x86_thread_state64_t    state = void;
            mach_msg_type_number_t  count = x86_THREAD_STATE64_COUNT;

            if ( thread_get_state( t.m_tdescr.tmach, x86_THREAD_STATE64, &state, &count ) != KERN_SUCCESS )
                onThreadError( "Unable to load thread state" );
            if ( !t.m_lock )
                t.m_curr.tstack = cast(void*) state.rsp;
            // rax,rbx,rcx,rdx,rdi,rsi,rbp,rsp
            t.m_reg[0] = state.rax;
            t.m_reg[1] = state.rbx;
            t.m_reg[2] = state.rcx;
            t.m_reg[3] = state.rdx;
            t.m_reg[4] = state.rdi;
            t.m_reg[5] = state.rsi;
            t.m_reg[6] = state.rbp;
            t.m_reg[7] = state.rsp;
            // r8,r9,r10,r11,r12,r13,r14,r15
            t.m_reg[8]  = state.r8;
            t.m_reg[9]  = state.r9;
            t.m_reg[10] = state.r10;
            t.m_reg[11] = state.r11;
            t.m_reg[12] = state.r12;
            t.m_reg[13] = state.r13;
            t.m_reg[14] = state.r14;
            t.m_reg[15] = state.r15;
        }
        else version (AArch64)
        {
            arm_thread_state64_t state = void;
            mach_msg_type_number_t count = ARM_THREAD_STATE64_COUNT;

            if (thread_get_state(t.m_tdescr.tmach, ARM_THREAD_STATE64, &state, &count) != KERN_SUCCESS)
                onThreadError("Unable to load thread state");
            // TODO: ThreadException here recurses forever!  Does it
            //still using onThreadError?
            //printf("state count %d (expect %d)\n", count ,ARM_THREAD_STATE64_COUNT);
            if (!t.m_lock)
                t.m_curr.tstack = cast(void*) state.sp;

            t.m_reg[0..29] = state.x;  // x0-x28
            t.m_reg[29] = state.fp;    // x29
            t.m_reg[30] = state.lr;    // x30
            t.m_reg[31] = state.sp;    // x31
            t.m_reg[32] = state.pc;
        }
        else version (ARM)
        {
            arm_thread_state32_t state = void;
            mach_msg_type_number_t count = ARM_THREAD_STATE32_COUNT;

            // Thought this would be ARM_THREAD_STATE32, but that fails.
            // Mystery
            if (thread_get_state(t.m_tdescr.tmach, ARM_THREAD_STATE, &state, &count) != KERN_SUCCESS)
                onThreadError("Unable to load thread state");
            // TODO: in past, ThreadException here recurses forever!  Does it
            //still using onThreadError?
            //printf("state count %d (expect %d)\n", count ,ARM_THREAD_STATE32_COUNT);
            if (!t.m_lock)
                t.m_curr.tstack = cast(void*) state.sp;

            t.m_reg[0..13] = state.r;  // r0 - r13
            t.m_reg[13] = state.sp;
            t.m_reg[14] = state.lr;
            t.m_reg[15] = state.pc;
        }
        else version (PPC)
        {
            ppc_thread_state_t state = void;
            mach_msg_type_number_t count = PPC_THREAD_STATE_COUNT;

            if (thread_get_state(t.m_tdescr.tmach, PPC_THREAD_STATE, &state, &count) != KERN_SUCCESS)
                onThreadError("Unable to load thread state");
            if (!t.m_lock)
                t.m_curr.tstack = cast(void*) state.r[1];
            t.m_reg[] = state.r[];
        }
        else version (PPC64)
        {
            ppc_thread_state64_t state = void;
            mach_msg_type_number_t count = PPC_THREAD_STATE64_COUNT;

            if (thread_get_state(t.m_tdescr.tmach, PPC_THREAD_STATE64, &state, &count) != KERN_SUCCESS)
                onThreadError("Unable to load thread state");
            if (!t.m_lock)
                t.m_curr.tstack = cast(void*) state.r[1];
            t.m_reg[] = state.r[];
        }
        else
        {
            static assert(false, "Architecture not supported." );
        }
    }
    else version (Solaris)
    {
        if (!sameThread)
        {
            static int getLwpStatus(ulong lwpid, out lwpstatus_t status)
            {
                import core.sys.posix.fcntl : open, O_RDONLY;
                import core.sys.posix.unistd : pread, close;
                import core.internal.string : unsignedToTempString;

                char[100] path = void;
                auto pslice = path[0 .. $];
                immutable n = unsignedToTempString(lwpid);
                immutable ndigits = n.length;

                // Construct path "/proc/self/lwp/%u/lwpstatus"
                pslice[0 .. 15] = "/proc/self/lwp/";
                pslice = pslice[15 .. $];
                pslice[0 .. ndigits] = n[];
                pslice = pslice[ndigits .. $];
                pslice[0 .. 10] = "/lwpstatus";
                pslice[10] = '\0';

                // Read in lwpstatus data
                int fd = open(path.ptr, O_RDONLY, 0);
                if (fd >= 0)
                {
                    while (pread(fd, &status, status.sizeof, 0) == status.sizeof)
                    {
                        // Should only attempt to read the thread state once it
                        // has been stopped by thr_suspend
                        if (status.pr_flags & PR_STOPPED)
                        {
                            close(fd);
                            return 0;
                        }
                        // Give it a chance to stop
                        thread_yield();
                    }
                    close(fd);
                }
                return -1;
            }

            lwpstatus_t status = void;
            if (getLwpStatus(t.m_tdescr.tid, status) != 0)
                onThreadError("Unable to load thread state");

            version (X86)
            {
                import core.sys.solaris.sys.regset; // REG_xxx

                if (!t.m_lock)
                    t.m_curr.tstack = cast(void*) status.pr_reg[REG_ESP];
                // eax,ebx,ecx,edx,edi,esi,ebp,esp
                t.m_reg[0] = status.pr_reg[REG_EAX];
                t.m_reg[1] = status.pr_reg[REG_EBX];
                t.m_reg[2] = status.pr_reg[REG_ECX];
                t.m_reg[3] = status.pr_reg[REG_EDX];
                t.m_reg[4] = status.pr_reg[REG_EDI];
                t.m_reg[5] = status.pr_reg[REG_ESI];
                t.m_reg[6] = status.pr_reg[REG_EBP];
                t.m_reg[7] = status.pr_reg[REG_ESP];
            }
            else version (X86_64)
            {
                import core.sys.solaris.sys.regset; // REG_xxx

                if (!t.m_lock)
                    t.m_curr.tstack = cast(void*) status.pr_reg[REG_RSP];
                // rax,rbx,rcx,rdx,rdi,rsi,rbp,rsp
                t.m_reg[0] = status.pr_reg[REG_RAX];
                t.m_reg[1] = status.pr_reg[REG_RBX];
                t.m_reg[2] = status.pr_reg[REG_RCX];
                t.m_reg[3] = status.pr_reg[REG_RDX];
                t.m_reg[4] = status.pr_reg[REG_RDI];
                t.m_reg[5] = status.pr_reg[REG_RSI];
                t.m_reg[6] = status.pr_reg[REG_RBP];
                t.m_reg[7] = status.pr_reg[REG_RSP];
                // r8,r9,r10,r11,r12,r13,r14,r15
                t.m_reg[8] = status.pr_reg[REG_R8];
                t.m_reg[9] = status.pr_reg[REG_R9];
                t.m_reg[10] = status.pr_reg[REG_R10];
                t.m_reg[11] = status.pr_reg[REG_R11];
                t.m_reg[12] = status.pr_reg[REG_R12];
                t.m_reg[13] = status.pr_reg[REG_R13];
                t.m_reg[14] = status.pr_reg[REG_R14];
                t.m_reg[15] = status.pr_reg[REG_R15];
            }
            else version (SPARC)
            {
                import core.sys.solaris.sys.procfs : R_SP, R_PC;

                if (!t.m_lock)
                    t.m_curr.tstack = cast(void*) status.pr_reg[R_SP];
                // g0..g7, o0..o7, l0..l7, i0..i7
                t.m_reg[0 .. 32] = status.pr_reg[0 .. 32];
                // pc
                t.m_reg[32] = status.pr_reg[R_PC];
            }
            else version (SPARC64)
            {
                import core.sys.solaris.sys.procfs : R_SP, R_PC;

                if (!t.m_lock)
                {
                    // SPARC V9 has a stack bias of 2047 bytes which must be added to get
                    // the actual data of the stack frame.
                    auto tstack = status.pr_reg[R_SP] + 2047;
                    assert(tstack % 16 == 0);
                    t.m_curr.tstack = cast(void*) tstack;
                }
                // g0..g7, o0..o7, l0..l7, i0..i7
                t.m_reg[0 .. 32] = status.pr_reg[0 .. 32];
                // pc
                t.m_reg[32] = status.pr_reg[R_PC];
            }
            else
            {
                static assert(false, "Architecture not supported.");
            }
        }
        else if (!t.m_lock)
        {
            t.m_curr.tstack = getStackTop();
        }
    }
    else // other Posix
    {
        if (sameThread && !t.m_lock)
        {
            t.m_curr.tstack = getStackTop();
        }
    }
}

package void purgeStackAndRegInfo(Thread t, const bool sameThread) nothrow @nogc
{
    version (Darwin)
    {
        t.unloadStackInfo();
        t.m_reg[0 .. $] = 0;
    }
    else version (Solaris)
    {
        t.unloadStackInfo();
        t.m_reg[0 .. $] = 0;
    }
    else
    {
        if (sameThread)
            t.unloadStackInfo();
    }
}

version (CoreDdoc) {} else
public  alias getpid = imported!"core.sys.posix.unistd".getpid;

package alias gettid = imported!"core.sys.posix.pthread".pthread_self;

package struct LLThreadProperties
{
    void delegate() nothrow dg;

    // Returns: false if error occurred
    bool initialize(void delegate() nothrow dg, ref LLThreadContext context) nothrow @nogc
    {
        this.dg = dg;
        return true;
    }
}

package struct LLThreadContext
{
    ThreadID tid;
    uint stacksize;

    this(uint stacksize, void delegate() nothrow cbDllUnload) nothrow @nogc
    {
        this.stacksize = stacksize;
        // cbDllUnload ignored, TODO: remove it from args list
    }
}

// Returns: false if error occurred
package bool launchLLThread(LLThreadProperties* tprop, ref LLThreadContext context, ref ll_ThreadData curr_llt) nothrow @nogc
{
    static extern (C) void* thread_lowlevelEntry(void* ctx) nothrow
    {
        auto tprop = *cast(LLThreadProperties*) ctx;
        free(ctx);

        tprop.dg();
        ll_removeThread(pthread_self());
        return null;
    }

    size_t stksz = adjustStackSize(context.stacksize);

    pthread_attr_t  attr;

    int rc;
    if ((rc = pthread_attr_init(&attr)) != 0)
        return false;
    if (stksz && (rc = pthread_attr_setstacksize(&attr, stksz)) != 0)
        return false;
    if ((rc = pthread_create(&context.tid, &attr, &thread_lowlevelEntry, tprop)) != 0)
        return false;
    rc = pthread_attr_destroy(&attr);
    assert(rc == 0);

    curr_llt.tid = context.tid;

    return true;
}

private size_t adjustStackSize(size_t sz) nothrow @nogc
{
    import core.memory: pageSize;
    import core.thread.types: PTHREAD_STACK_MIN;

    if (sz == 0)
        return 0;

    // stack size must be at least PTHREAD_STACK_MIN for most platforms.
    if (PTHREAD_STACK_MIN > sz)
        sz = PTHREAD_STACK_MIN;

    version (CRuntime_Glibc)
    {
        // On glibc, TLS uses the top of the stack, so add its size to the requested size
        sz += externDFunc!("rt.sections_elf_shared.sizeOfTLS",
                           size_t function() @nogc nothrow)();
    }

    // stack size must be a multiple of pageSize
    sz = ((sz + pageSize - 1) & ~(pageSize - 1));

    return sz;
}

version (CoreDdoc) {} else
void joinLowLevelThread(ThreadID tid) nothrow @nogc
{
    if (pthread_join(tid, null) != 0)
        onThreadError("Unable to join thread");
}
