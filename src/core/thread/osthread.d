/**
 * The osthread module provides low-level, OS-dependent code
 * for thread creation and management.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly, Walter Bright, Alex Rønne Petersen, Martin Nowak
 * Source:    $(DRUNTIMESRC core/thread/osthread.d)
 */

module core.thread.osthread;

import core.thread.context;
import core.time;
import core.exception : onOutOfMemoryError;

///////////////////////////////////////////////////////////////////////////////
// Platform Detection and Memory Allocation
///////////////////////////////////////////////////////////////////////////////

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (D_InlineAsm_X86)
{
    version (Windows)
        version = AsmX86_Windows;
    else version (Posix)
        version = AsmX86_Posix;
}
else version (D_InlineAsm_X86_64)
{
    version (Windows)
    {
        version = AsmX86_64_Windows;
    }
    else version (Posix)
    {
        version = AsmX86_64_Posix;
    }
}

version (Posix)
{
    import core.sys.posix.unistd;

    version (AsmX86_Windows)    {} else
    version (AsmX86_Posix)      {} else
    version (AsmX86_64_Windows) {} else
    version (AsmX86_64_Posix)   {} else
    version (AsmExternal)       {} else
    {
        // NOTE: The ucontext implementation requires architecture specific
        //       data definitions to operate so testing for it must be done
        //       by checking for the existence of ucontext_t rather than by
        //       a version identifier.  Please note that this is considered
        //       an obsolescent feature according to the POSIX spec, so a
        //       custom solution is still preferred.
        import core.sys.posix.ucontext;
    }
}

package(core.thread)
{
    static immutable size_t PAGESIZE;
    version (Posix) static immutable size_t PTHREAD_STACK_MIN;
}

shared static this()
{
    version (Windows)
    {
        SYSTEM_INFO info;
        GetSystemInfo(&info);

        PAGESIZE = info.dwPageSize;
        assert(PAGESIZE < int.max);
    }
    else version (Posix)
    {
        PAGESIZE = cast(size_t)sysconf(_SC_PAGESIZE);
        PTHREAD_STACK_MIN = cast(size_t)sysconf(_SC_THREAD_STACK_MIN);
    }
    else
    {
        static assert(0, "unimplemented");
    }
}

private
{
    // interface to rt.tlsgc
    import core.internal.traits : externDFunc;

    alias rt_tlsgc_init = externDFunc!("rt.tlsgc.init", void* function() nothrow @nogc);
    alias rt_tlsgc_destroy = externDFunc!("rt.tlsgc.destroy", void function(void*) nothrow @nogc);

    alias ScanDg = void delegate(void* pstart, void* pend) nothrow;
    alias rt_tlsgc_scan =
        externDFunc!("rt.tlsgc.scan", void function(void*, scope ScanDg) nothrow);

    alias rt_tlsgc_processGCMarks =
        externDFunc!("rt.tlsgc.processGCMarks", void function(void*, scope IsMarkedDg) nothrow);
}

version (Solaris)
{
    import core.sys.solaris.sys.priocntl;
    import core.sys.solaris.sys.types;
    import core.sys.posix.sys.wait : idtype_t;
}

version (GNU)
{
    import gcc.builtins;
    version (GNU_StackGrowsDown)
        version = StackGrowsDown;
}
else
{
    // this should be true for most architectures
    version = StackGrowsDown;
}

/**
 * Returns the process ID of the calling process, which is guaranteed to be
 * unique on the system. This call is always successful.
 *
 * Example:
 * ---
 * writefln("Current process id: %s", getpid());
 * ---
 */
version (Posix)
{
    alias getpid = core.sys.posix.unistd.getpid;
}
else version (Windows)
{
    alias getpid = core.sys.windows.winbase.GetCurrentProcessId;
}


///////////////////////////////////////////////////////////////////////////////
// Thread and Fiber Exceptions
///////////////////////////////////////////////////////////////////////////////


/**
 * Base class for thread exceptions.
 */
class ThreadException : Exception
{
    @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }

    @safe pure nothrow this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, next);
    }
}


/**
* Base class for thread errors to be used for function inside GC when allocations are unavailable.
*/
class ThreadError : Error
{
    @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }

    @safe pure nothrow this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, next);
    }
}

private
{
    import core.atomic, core.memory, core.sync.mutex;

    // Handling unaligned mutexes are not supported on all platforms, so we must
    // ensure that the address of all shared data are appropriately aligned.
    import core.internal.traits : classInstanceAlignment;

    enum mutexAlign = classInstanceAlignment!Mutex;
    enum mutexClassInstanceSize = __traits(classInstanceSize, Mutex);

    //
    // exposed by compiler runtime
    //
    extern (C) void  rt_moduleTlsCtor();
    extern (C) void  rt_moduleTlsDtor();

    /**
     * Hook for whatever EH implementation is used to save/restore some data
     * per stack.
     *
     * Params:
     *     newContext = The return value of the prior call to this function
     *         where the stack was last swapped out, or null when a fiber stack
     *         is switched in for the first time.
     */
    extern(C) void* _d_eh_swapContext(void* newContext) nothrow @nogc;

    version (DigitalMars)
    {
        version (Windows)
            alias swapContext = _d_eh_swapContext;
        else
        {
            extern(C) void* _d_eh_swapContextDwarf(void* newContext) nothrow @nogc;

            void* swapContext(void* newContext) nothrow @nogc
            {
                /* Detect at runtime which scheme is being used.
                 * Eventually, determine it statically.
                 */
                static int which = 0;
                final switch (which)
                {
                    case 0:
                    {
                        assert(newContext == null);
                        auto p = _d_eh_swapContext(newContext);
                        auto pdwarf = _d_eh_swapContextDwarf(newContext);
                        if (p)
                        {
                            which = 1;
                            return p;
                        }
                        else if (pdwarf)
                        {
                            which = 2;
                            return pdwarf;
                        }
                        return null;
                    }
                    case 1:
                        return _d_eh_swapContext(newContext);
                    case 2:
                        return _d_eh_swapContextDwarf(newContext);
                }
            }
        }
    }
    else
        alias swapContext = _d_eh_swapContext;
}


///////////////////////////////////////////////////////////////////////////////
// Thread Entry Point and Signal Handlers
///////////////////////////////////////////////////////////////////////////////


version (Windows)
{
    private
    {
        import core.stdc.stdint : uintptr_t; // for _beginthreadex decl below
        import core.stdc.stdlib;             // for malloc, atexit
        import core.sys.windows.basetsd /+: HANDLE+/;
        import core.sys.windows.threadaux /+: getThreadStackBottom, impersonate_thread, OpenThreadHandle+/;
        import core.sys.windows.winbase /+: CloseHandle, CREATE_SUSPENDED, DuplicateHandle, GetCurrentThread,
            GetCurrentThreadId, GetCurrentProcess, GetExitCodeThread, GetSystemInfo, GetThreadContext,
            GetThreadPriority, INFINITE, ResumeThread, SetThreadPriority, Sleep,  STILL_ACTIVE,
            SuspendThread, SwitchToThread, SYSTEM_INFO, THREAD_PRIORITY_IDLE, THREAD_PRIORITY_NORMAL,
            THREAD_PRIORITY_TIME_CRITICAL, WAIT_OBJECT_0, WaitForSingleObject+/;
        import core.sys.windows.windef /+: TRUE+/;
        import core.sys.windows.winnt /+: CONTEXT, CONTEXT_CONTROL, CONTEXT_INTEGER+/;

        extern (Windows) alias btex_fptr = uint function(void*);
        extern (C) uintptr_t _beginthreadex(void*, uint, btex_fptr, void*, uint, uint*) nothrow @nogc;

        //
        // Entry point for Windows threads
        //
        extern (Windows) uint thread_entryPoint( void* arg ) nothrow
        {
            Thread  obj = cast(Thread) arg;
            assert( obj );

            assert( obj.m_curr is &obj.m_main );
            obj.m_main.bstack = getStackBottom();
            obj.m_main.tstack = obj.m_main.bstack;
            obj.m_tlsgcdata = rt_tlsgc_init();

            Thread.setThis(obj);
            Thread.add(obj);
            scope (exit)
            {
                Thread.remove(obj);
                rt_tlsgc_destroy( obj.m_tlsgcdata );
                obj.m_tlsgcdata = null;
            }
            Thread.add(&obj.m_main);

            // NOTE: No GC allocations may occur until the stack pointers have
            //       been set and Thread.getThis returns a valid reference to
            //       this thread object (this latter condition is not strictly
            //       necessary on Windows but it should be followed for the
            //       sake of consistency).

            // TODO: Consider putting an auto exception object here (using
            //       alloca) forOutOfMemoryError plus something to track
            //       whether an exception is in-flight?

            void append( Throwable t )
            {
                obj.m_unhandled = Throwable.chainTogether(obj.m_unhandled, t);
            }

            version (D_InlineAsm_X86)
            {
                asm nothrow @nogc { fninit; }
            }

            try
            {
                rt_moduleTlsCtor();
                try
                {
                    obj.run();
                }
                catch ( Throwable t )
                {
                    append( t );
                }
                rt_moduleTlsDtor();
            }
            catch ( Throwable t )
            {
                append( t );
            }
            return 0;
        }


        HANDLE GetCurrentThreadHandle() nothrow @nogc
        {
            const uint DUPLICATE_SAME_ACCESS = 0x00000002;

            HANDLE curr = GetCurrentThread(),
                   proc = GetCurrentProcess(),
                   hndl;

            DuplicateHandle( proc, curr, proc, &hndl, 0, TRUE, DUPLICATE_SAME_ACCESS );
            return hndl;
        }
    }
}
else version (Posix)
{
    private
    {
        import core.stdc.errno;
        import core.sys.posix.semaphore;
        import core.sys.posix.stdlib; // for malloc, valloc, free, atexit
        import core.sys.posix.pthread;
        import core.sys.posix.signal;
        import core.sys.posix.time;

        version (Darwin)
        {
            import core.sys.darwin.mach.thread_act;
            import core.sys.darwin.pthread : pthread_mach_thread_np;
        }

        //
        // Entry point for POSIX threads
        //
        extern (C) void* thread_entryPoint( void* arg ) nothrow
        {
            version (Shared)
            {
                Thread obj = cast(Thread)(cast(void**)arg)[0];
                auto loadedLibraries = (cast(void**)arg)[1];
                .free(arg);
            }
            else
            {
                Thread obj = cast(Thread)arg;
            }
            assert( obj );

            // loadedLibraries need to be inherited from parent thread
            // before initilizing GC for TLS (rt_tlsgc_init)
            version (Shared)
            {
                externDFunc!("rt.sections_elf_shared.inheritLoadedLibraries",
                             void function(void*) @nogc nothrow)(loadedLibraries);
            }

            assert( obj.m_curr is &obj.m_main );
            obj.m_main.bstack = getStackBottom();
            obj.m_main.tstack = obj.m_main.bstack;
            obj.m_tlsgcdata = rt_tlsgc_init();

            atomicStore!(MemoryOrder.raw)(obj.m_isRunning, true);
            Thread.setThis(obj); // allocates lazy TLS (see Issue 11981)
            Thread.add(obj);     // can only receive signals from here on
            scope (exit)
            {
                Thread.remove(obj);
                atomicStore!(MemoryOrder.raw)(obj.m_isRunning, false);
                rt_tlsgc_destroy( obj.m_tlsgcdata );
                obj.m_tlsgcdata = null;
            }
            Thread.add(&obj.m_main);

            static extern (C) void thread_cleanupHandler( void* arg ) nothrow @nogc
            {
                Thread  obj = cast(Thread) arg;
                assert( obj );

                // NOTE: If the thread terminated abnormally, just set it as
                //       not running and let thread_suspendAll remove it from
                //       the thread list.  This is safer and is consistent
                //       with the Windows thread code.
                atomicStore!(MemoryOrder.raw)(obj.m_isRunning,false);
            }

            // NOTE: Using void to skip the initialization here relies on
            //       knowledge of how pthread_cleanup is implemented.  It may
            //       not be appropriate for all platforms.  However, it does
            //       avoid the need to link the pthread module.  If any
            //       implementation actually requires default initialization
            //       then pthread_cleanup should be restructured to maintain
            //       the current lack of a link dependency.
            static if ( __traits( compiles, pthread_cleanup ) )
            {
                pthread_cleanup cleanup = void;
                cleanup.push( &thread_cleanupHandler, cast(void*) obj );
            }
            else static if ( __traits( compiles, pthread_cleanup_push ) )
            {
                pthread_cleanup_push( &thread_cleanupHandler, cast(void*) obj );
            }
            else
            {
                static assert( false, "Platform not supported." );
            }

            // NOTE: No GC allocations may occur until the stack pointers have
            //       been set and Thread.getThis returns a valid reference to
            //       this thread object (this latter condition is not strictly
            //       necessary on Windows but it should be followed for the
            //       sake of consistency).

            // TODO: Consider putting an auto exception object here (using
            //       alloca) forOutOfMemoryError plus something to track
            //       whether an exception is in-flight?

            void append( Throwable t )
            {
                obj.m_unhandled = Throwable.chainTogether(obj.m_unhandled, t);
            }
            try
            {
                rt_moduleTlsCtor();
                try
                {
                    obj.run();
                }
                catch ( Throwable t )
                {
                    append( t );
                }
                rt_moduleTlsDtor();
                version (Shared)
                {
                    externDFunc!("rt.sections_elf_shared.cleanupLoadedLibraries",
                                 void function() @nogc nothrow)();
                }
            }
            catch ( Throwable t )
            {
                append( t );
            }

            // NOTE: Normal cleanup is handled by scope(exit).

            static if ( __traits( compiles, pthread_cleanup ) )
            {
                cleanup.pop( 0 );
            }
            else static if ( __traits( compiles, pthread_cleanup_push ) )
            {
                pthread_cleanup_pop( 0 );
            }

            return null;
        }


        //
        // Used to track the number of suspended threads
        //
        __gshared sem_t suspendCount;


        extern (C) void thread_suspendHandler( int sig ) nothrow
        in
        {
            assert( sig == suspendSignalNumber );
        }
        do
        {
            void op(void* sp) nothrow
            {
                // NOTE: Since registers are being pushed and popped from the
                //       stack, any other stack data used by this function should
                //       be gone before the stack cleanup code is called below.
                Thread obj = Thread.getThis();
                assert(obj !is null);

                if ( !obj.m_lock )
                {
                    obj.m_curr.tstack = getStackTop();
                }

                sigset_t    sigres = void;
                int         status;

                status = sigfillset( &sigres );
                assert( status == 0 );

                status = sigdelset( &sigres, resumeSignalNumber );
                assert( status == 0 );

                version (FreeBSD) obj.m_suspendagain = false;
                status = sem_post( &suspendCount );
                assert( status == 0 );

                sigsuspend( &sigres );

                if ( !obj.m_lock )
                {
                    obj.m_curr.tstack = obj.m_curr.bstack;
                }
            }

            // avoid deadlocks on FreeBSD, see Issue 13416
            version (FreeBSD)
            {
                auto obj = Thread.getThis();
                if (THR_IN_CRITICAL(obj.m_addr))
                {
                    obj.m_suspendagain = true;
                    if (sem_post(&suspendCount)) assert(0);
                    return;
                }
            }

            callWithStackShell(&op);
        }


        extern (C) void thread_resumeHandler( int sig ) nothrow
        in
        {
            assert( sig == resumeSignalNumber );
        }
        do
        {

        }

        // HACK libthr internal (thr_private.h) macro, used to
        // avoid deadlocks in signal handler, see Issue 13416
        version (FreeBSD) bool THR_IN_CRITICAL(pthread_t p) nothrow @nogc
        {
            import core.sys.posix.config : c_long;
            import core.sys.posix.sys.types : lwpid_t;

            // If the begin of pthread would be changed in libthr (unlikely)
            // we'll run into undefined behavior, compare with thr_private.h.
            static struct pthread
            {
                c_long tid;
                static struct umutex { lwpid_t owner; uint flags; uint[2] ceilings; uint[4] spare; }
                umutex lock;
                uint cycle;
                int locklevel;
                int critical_count;
                // ...
            }
            auto priv = cast(pthread*)p;
            return priv.locklevel > 0 || priv.critical_count > 0;
        }
    }
}
else
{
    // NOTE: This is the only place threading versions are checked.  If a new
    //       version is added, the module code will need to be searched for
    //       places where version-specific code may be required.  This can be
    //       easily accomlished by searching for 'Windows' or 'Posix'.
    static assert( false, "Unknown threading implementation." );
}


///////////////////////////////////////////////////////////////////////////////
// Thread
///////////////////////////////////////////////////////////////////////////////


/**
 * This class encapsulates all threading functionality for the D
 * programming language.  As thread manipulation is a required facility
 * for garbage collection, all user threads should derive from this
 * class, and instances of this class should never be explicitly deleted.
 * A new thread may be created using either derivation or composition, as
 * in the following example.
 */
class Thread
{
    ///////////////////////////////////////////////////////////////////////////
    // Initialization
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Initializes a thread object which is associated with a static
     * D function.
     *
     * Params:
     *  fn = The thread function.
     *  sz = The stack size for this thread.
     *
     * In:
     *  fn must not be null.
     */
    this( void function() fn, size_t sz = 0 ) @safe pure nothrow @nogc
    in
    {
        assert( fn );
    }
    do
    {
        this(sz);
        m_call = fn;
        m_curr = &m_main;
    }


    /**
     * Initializes a thread object which is associated with a dynamic
     * D function.
     *
     * Params:
     *  dg = The thread function.
     *  sz = The stack size for this thread.
     *
     * In:
     *  dg must not be null.
     */
    this( void delegate() dg, size_t sz = 0 ) @safe pure nothrow @nogc
    in
    {
        assert( dg );
    }
    do
    {
        this(sz);
        m_call = dg;
        m_curr = &m_main;
    }


    /**
     * Cleans up any remaining resources used by this object.
     */
    ~this() nothrow @nogc
    {
        if (m_tlsgcdata !is null)
        {
            rt_tlsgc_destroy( m_tlsgcdata );
            m_tlsgcdata = null;
        }

        bool no_context = m_addr == m_addr.init;
        bool not_registered = !next && !prev && (sm_tbeg !is this);

        if (no_context || not_registered)
        {
            return;
        }

        version (Windows)
        {
            m_addr = m_addr.init;
            CloseHandle( m_hndl );
            m_hndl = m_hndl.init;
        }
        else version (Posix)
        {
            pthread_detach( m_addr );
            m_addr = m_addr.init;
        }
        version (Darwin)
        {
            m_tmach = m_tmach.init;
        }
    }


    ///////////////////////////////////////////////////////////////////////////
    // General Actions
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Starts the thread and invokes the function or delegate passed upon
     * construction.
     *
     * In:
     *  This routine may only be called once per thread instance.
     *
     * Throws:
     *  ThreadException if the thread fails to start.
     */
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

        version (Windows) {} else
        version (Posix)
        {
            size_t stksz = adjustStackSize( m_sz );

            pthread_attr_t  attr;

            if ( pthread_attr_init( &attr ) )
                onThreadError( "Error initializing thread attributes" );
            if ( stksz && pthread_attr_setstacksize( &attr, stksz ) )
                onThreadError( "Error initializing thread stack size" );
        }

        version (Windows)
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
            ++nAboutToStart;
            pAboutToStart = cast(Thread*)realloc(pAboutToStart, Thread.sizeof * nAboutToStart);
            pAboutToStart[nAboutToStart - 1] = this;
            version (Windows)
            {
                if ( ResumeThread( m_hndl ) == -1 )
                    onThreadError( "Error resuming thread" );
            }
            else version (Posix)
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
                    if ( pthread_create( &m_addr, &attr, &thread_entryPoint, ps ) != 0 )
                    {
                        externDFunc!("rt.sections_elf_shared.unpinLoadedLibraries",
                                     void function(void*) @nogc nothrow)(libs);
                        .free(ps);
                        onThreadError( "Error creating thread" );
                    }
                }
                else
                {
                    if ( pthread_create( &m_addr, &attr, &thread_entryPoint, cast(void*) this ) != 0 )
                        onThreadError( "Error creating thread" );
                }
                if ( pthread_attr_destroy( &attr ) != 0 )
                    onThreadError( "Error destroying thread attributes" );
            }
            version (Darwin)
            {
                m_tmach = pthread_mach_thread_np( m_addr );
                if ( m_tmach == m_tmach.init )
                    onThreadError( "Error creating thread" );
            }

            return this;
        }
    }

    /**
     * Waits for this thread to complete.  If the thread terminated as the
     * result of an unhandled exception, this exception will be rethrown.
     *
     * Params:
     *  rethrow = Rethrow any unhandled exception which may have caused this
     *            thread to terminate.
     *
     * Throws:
     *  ThreadException if the operation fails.
     *  Any exception not handled by the joined thread.
     *
     * Returns:
     *  Any exception not handled by this thread if rethrow = false, null
     *  otherwise.
     */
    final Throwable join( bool rethrow = true )
    {
        version (Windows)
        {
            if ( WaitForSingleObject( m_hndl, INFINITE ) != WAIT_OBJECT_0 )
                throw new ThreadException( "Unable to join thread" );
            // NOTE: m_addr must be cleared before m_hndl is closed to avoid
            //       a race condition with isRunning. The operation is done
            //       with atomicStore to prevent compiler reordering.
            atomicStore!(MemoryOrder.raw)(*cast(shared)&m_addr, m_addr.init);
            CloseHandle( m_hndl );
            m_hndl = m_hndl.init;
        }
        else version (Posix)
        {
            if ( pthread_join( m_addr, null ) != 0 )
                throw new ThreadException( "Unable to join thread" );
            // NOTE: pthread_join acts as a substitute for pthread_detach,
            //       which is normally called by the dtor.  Setting m_addr
            //       to zero ensures that pthread_detach will not be called
            //       on object destruction.
            m_addr = m_addr.init;
        }
        if ( m_unhandled )
        {
            if ( rethrow )
                throw m_unhandled;
            return m_unhandled;
        }
        return null;
    }


    ///////////////////////////////////////////////////////////////////////////
    // General Properties
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Gets the OS identifier for this thread.
     *
     * Returns:
     *  If the thread hasn't been started yet, returns $(LREF ThreadID)$(D.init).
     *  Otherwise, returns the result of $(D GetCurrentThreadId) on Windows,
     *  and $(D pthread_self) on POSIX.
     *
     *  The value is unique for the current process.
     */
    final @property ThreadID id() @safe @nogc
    {
        synchronized( this )
        {
            return m_addr;
        }
    }


    /**
     * Gets the user-readable label for this thread.
     *
     * Returns:
     *  The name of this thread.
     */
    final @property string name() @safe @nogc
    {
        synchronized( this )
        {
            return m_name;
        }
    }


    /**
     * Sets the user-readable label for this thread.
     *
     * Params:
     *  val = The new name of this thread.
     */
    final @property void name( string val ) @safe @nogc
    {
        synchronized( this )
        {
            m_name = val;
        }
    }


    /**
     * Gets the daemon status for this thread.  While the runtime will wait for
     * all normal threads to complete before tearing down the process, daemon
     * threads are effectively ignored and thus will not prevent the process
     * from terminating.  In effect, daemon threads will be terminated
     * automatically by the OS when the process exits.
     *
     * Returns:
     *  true if this is a daemon thread.
     */
    final @property bool isDaemon() @safe @nogc
    {
        synchronized( this )
        {
            return m_isDaemon;
        }
    }


    /**
     * Sets the daemon status for this thread.  While the runtime will wait for
     * all normal threads to complete before tearing down the process, daemon
     * threads are effectively ignored and thus will not prevent the process
     * from terminating.  In effect, daemon threads will be terminated
     * automatically by the OS when the process exits.
     *
     * Params:
     *  val = The new daemon status for this thread.
     */
    final @property void isDaemon( bool val ) @safe @nogc
    {
        synchronized( this )
        {
            m_isDaemon = val;
        }
    }

    /**
     * Tests whether this thread is the main thread, i.e. the thread
     * that initialized the runtime
     *
     * Returns:
     *  true if the thread is the main thread
     */
    final @property bool isMainThread() nothrow @nogc
    {
        return this is sm_main;
    }

    /**
     * Tests whether this thread is running.
     *
     * Returns:
     *  true if the thread is running, false if not.
     */
    final @property bool isRunning() nothrow @nogc
    {
        if ( m_addr == m_addr.init )
        {
            return false;
        }

        version (Windows)
        {
            uint ecode = 0;
            GetExitCodeThread( m_hndl, &ecode );
            return ecode == STILL_ACTIVE;
        }
        else version (Posix)
        {
            return atomicLoad(m_isRunning);
        }
    }


    ///////////////////////////////////////////////////////////////////////////
    // Thread Priority Actions
    ///////////////////////////////////////////////////////////////////////////

    version (Windows)
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
    else
    {
        private struct Priority
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
            cache = loadPriorities;
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
                    result.PRIORITY_MIN = -clinfo[0];
                    // by definition
                    result.PRIORITY_DEFAULT = 0;
                }
            }
            else version (Posix)
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
            else
            {
                static assert(0, "Your code here.");
            }
            return result;
        }

        /**
         * The minimum scheduling priority that may be set for a thread.  On
         * systems where multiple scheduling policies are defined, this value
         * represents the minimum valid priority for the scheduling policy of
         * the process.
         */
        @property static int PRIORITY_MIN() @nogc nothrow pure @trusted
        {
            return (cast(int function() @nogc nothrow pure @safe)
                &loadGlobal!"PRIORITY_MIN")();
        }

        /**
         * The maximum scheduling priority that may be set for a thread.  On
         * systems where multiple scheduling policies are defined, this value
         * represents the maximum valid priority for the scheduling policy of
         * the process.
         */
        @property static const(int) PRIORITY_MAX() @nogc nothrow pure @trusted
        {
            return (cast(int function() @nogc nothrow pure @safe)
                &loadGlobal!"PRIORITY_MAX")();
        }

        /**
         * The default scheduling priority that is set for a thread.  On
         * systems where multiple scheduling policies are defined, this value
         * represents the default priority for the scheduling policy of
         * the process.
         */
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

    /**
     * Gets the scheduling priority for the associated thread.
     *
     * Note: Getting the priority of a thread that already terminated
     * might return the default priority.
     *
     * Returns:
     *  The scheduling priority of this thread.
     */
    final @property int priority()
    {
        version (Windows)
        {
            return GetThreadPriority( m_hndl );
        }
        else version (NetBSD)
        {
           return fakePriority==int.max? PRIORITY_DEFAULT : fakePriority;
        }
        else version (Posix)
        {
            int         policy;
            sched_param param;

            if (auto err = pthread_getschedparam(m_addr, &policy, &param))
            {
                // ignore error if thread is not running => Bugzilla 8960
                if (!atomicLoad(m_isRunning)) return PRIORITY_DEFAULT;
                throw new ThreadException("Unable to get thread priority");
            }
            return param.sched_priority;
        }
    }


    /**
     * Sets the scheduling priority for the associated thread.
     *
     * Note: Setting the priority of a thread that already terminated
     * might have no effect.
     *
     * Params:
     *  val = The new scheduling priority of this thread.
     */
    final @property void priority( int val )
    in
    {
        assert(val >= PRIORITY_MIN);
        assert(val <= PRIORITY_MAX);
    }
    do
    {
        version (Windows)
        {
            if ( !SetThreadPriority( m_hndl, val ) )
                throw new ThreadException( "Unable to set thread priority" );
        }
        else version (Solaris)
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
        else version (Posix)
        {
            static if (__traits(compiles, pthread_setschedprio))
            {
                if (auto err = pthread_setschedprio(m_addr, val))
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

                if (auto err = pthread_getschedparam(m_addr, &policy, &param))
                {
                    // ignore error if thread is not running => Bugzilla 8960
                    if (!atomicLoad(m_isRunning)) return;
                    throw new ThreadException("Unable to set thread priority");
                }
                param.sched_priority = val;
                if (auto err = pthread_setschedparam(m_addr, policy, &param))
                {
                    // ignore error if thread is not running => Bugzilla 8960
                    if (!atomicLoad(m_isRunning)) return;
                    throw new ThreadException("Unable to set thread priority");
                }
            }
        }
    }


    unittest
    {
        auto thr = Thread.getThis();
        immutable prio = thr.priority;
        scope (exit) thr.priority = prio;

        assert(prio == PRIORITY_DEFAULT);
        assert(prio >= PRIORITY_MIN && prio <= PRIORITY_MAX);
        thr.priority = PRIORITY_MIN;
        assert(thr.priority == PRIORITY_MIN);
        thr.priority = PRIORITY_MAX;
        assert(thr.priority == PRIORITY_MAX);
    }

    unittest // Bugzilla 8960
    {
        import core.sync.semaphore;

        auto thr = new Thread({});
        thr.start();
        Thread.sleep(1.msecs);       // wait a little so the thread likely has finished
        thr.priority = PRIORITY_MAX; // setting priority doesn't cause error
        auto prio = thr.priority;    // getting priority doesn't cause error
        assert(prio >= PRIORITY_MIN && prio <= PRIORITY_MAX);
    }

    ///////////////////////////////////////////////////////////////////////////
    // Actions on Calling Thread
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Suspends the calling thread for at least the supplied period.  This may
     * result in multiple OS calls if period is greater than the maximum sleep
     * duration supported by the operating system.
     *
     * Params:
     *  val = The minimum duration the calling thread should be suspended.
     *
     * In:
     *  period must be non-negative.
     *
     * Example:
     * ------------------------------------------------------------------------
     *
     * Thread.sleep( dur!("msecs")( 50 ) );  // sleep for 50 milliseconds
     * Thread.sleep( dur!("seconds")( 5 ) ); // sleep for 5 seconds
     *
     * ------------------------------------------------------------------------
     */
    static void sleep( Duration val ) @nogc nothrow
    in
    {
        assert( !val.isNegative );
    }
    do
    {
        version (Windows)
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
        else version (Posix)
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


    /**
     * Forces a context switch to occur away from the calling thread.
     */
    static void yield() @nogc nothrow
    {
        version (Windows)
            SwitchToThread();
        else version (Posix)
            sched_yield();
    }


    ///////////////////////////////////////////////////////////////////////////
    // Thread Accessors
    ///////////////////////////////////////////////////////////////////////////

    /**
     * Provides a reference to the calling thread.
     *
     * Returns:
     *  The thread object representing the calling thread.  The result of
     *  deleting this object is undefined.  If the current thread is not
     *  attached to the runtime, a null reference is returned.
     */
    static Thread getThis() @safe nothrow @nogc
    {
        // NOTE: This function may not be called until thread_init has
        //       completed.  See thread_suspendAll for more information
        //       on why this might occur.
        return sm_this;
    }


    /**
     * Provides a list of all threads currently being tracked by the system.
     * Note that threads in the returned array might no longer run (see
     * $(D Thread.)$(LREF isRunning)).
     *
     * Returns:
     *  An array containing references to all threads currently being
     *  tracked by the system.  The result of deleting any contained
     *  objects is undefined.
     */
    static Thread[] getAll()
    {
        static void resize(ref Thread[] buf, size_t nlen)
        {
            buf.length = nlen;
        }
        return getAllImpl!resize();
    }


    /**
     * Operates on all threads currently being tracked by the system.  The
     * result of deleting any Thread object is undefined.
     * Note that threads passed to the callback might no longer run (see
     * $(D Thread.)$(LREF isRunning)).
     *
     * Params:
     *  dg = The supplied code as a delegate.
     *
     * Returns:
     *  Zero if all elemented are visited, nonzero if not.
     */
    static int opApply(scope int delegate(ref Thread) dg)
    {
        import core.stdc.stdlib : free, realloc;

        static void resize(ref Thread[] buf, size_t nlen)
        {
            buf = (cast(Thread*)realloc(buf.ptr, nlen * Thread.sizeof))[0 .. nlen];
        }
        auto buf = getAllImpl!resize;
        scope(exit) if (buf.ptr) free(buf.ptr);

        foreach (t; buf)
        {
            if (auto res = dg(t))
                return res;
        }
        return 0;
    }

    unittest
    {
        auto t1 = new Thread({
            foreach (_; 0 .. 20)
                Thread.getAll;
        }).start;
        auto t2 = new Thread({
            foreach (_; 0 .. 20)
                GC.collect;
        }).start;
        t1.join();
        t2.join();
    }

    private static Thread[] getAllImpl(alias resize)()
    {
        import core.atomic;

        Thread[] buf;
        while (true)
        {
            immutable len = atomicLoad!(MemoryOrder.raw)(*cast(shared)&sm_tlen);
            resize(buf, len);
            assert(buf.length == len);
            synchronized (slock)
            {
                if (len == sm_tlen)
                {
                    size_t pos;
                    for (Thread t = sm_tbeg; t; t = t.next)
                        buf[pos++] = t;
                    return buf;
                }
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    // Stuff That Should Go Away
    ///////////////////////////////////////////////////////////////////////////


private:
    //
    // Initializes a thread object which has no associated executable function.
    // This is used for the main thread initialized in thread_init().
    //
    this(size_t sz = 0) @safe pure nothrow @nogc
    {
        m_sz = sz;
        m_curr = &m_main;
    }


    //
    // Thread entry point.  Invokes the function or delegate passed on
    // construction (if any).
    //
    final void run()
    {
        m_call();
    }

private:

    //
    // Standard types
    //
    version (Windows)
    {
        alias TLSKey = uint;
    }
    else version (Posix)
    {
        alias TLSKey = pthread_key_t;
    }


    //
    // Local storage
    //
    static Thread       sm_this;


    //
    // Main process thread
    //
    __gshared Thread    sm_main;

    version (FreeBSD)
    {
        // set when suspend failed and should be retried, see Issue 13416
        shared bool m_suspendagain;
    }


    //
    // Standard thread data
    //
    version (Windows)
    {
        HANDLE          m_hndl;
    }
    else version (Darwin)
    {
        mach_port_t     m_tmach;
    }
    ThreadID            m_addr;
    Callable            m_call;
    string              m_name;
    size_t              m_sz;
    version (Posix)
    {
        shared bool     m_isRunning;
    }
    bool                m_isDaemon;
    bool                m_isInCriticalRegion;
    Throwable           m_unhandled;

    version (Solaris)
    {
        __gshared bool m_isRTClass;
    }

private:
    ///////////////////////////////////////////////////////////////////////////
    // Storage of Active Thread
    ///////////////////////////////////////////////////////////////////////////


    //
    // Sets a thread-local reference to the current thread object.
    //
    static void setThis( Thread t ) nothrow @nogc
    {
        sm_this = t;
    }

package(core.thread):

    StackContext        m_main;
    StackContext*       m_curr;
    bool                m_lock;
    void*               m_tlsgcdata;

    ///////////////////////////////////////////////////////////////////////////
    // Thread Context and GC Scanning Support
    ///////////////////////////////////////////////////////////////////////////


    final void pushContext( StackContext* c ) nothrow @nogc
    in
    {
        assert( !c.within );
    }
    do
    {
        m_curr.ehContext = swapContext(c.ehContext);
        c.within = m_curr;
        m_curr = c;
    }


    final void popContext() nothrow @nogc
    in
    {
        assert( m_curr && m_curr.within );
    }
    do
    {
        StackContext* c = m_curr;
        m_curr = c.within;
        c.ehContext = swapContext(m_curr.ehContext);
        c.within = null;
    }

private:

    final StackContext* topContext() nothrow @nogc
    in
    {
        assert( m_curr );
    }
    do
    {
        return m_curr;
    }

    version (Windows)
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
    else version (Darwin)
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
        else
        {
            static assert(false, "Architecture not supported." );
        }
    }


package(core.thread):
    ///////////////////////////////////////////////////////////////////////////
    // GC Scanning Support
    ///////////////////////////////////////////////////////////////////////////


    // NOTE: The GC scanning process works like so:
    //
    //          1. Suspend all threads.
    //          2. Scan the stacks of all suspended threads for roots.
    //          3. Resume all threads.
    //
    //       Step 1 and 3 require a list of all threads in the system, while
    //       step 2 requires a list of all thread stacks (each represented by
    //       a Context struct).  Traditionally, there was one stack per thread
    //       and the Context structs were not necessary.  However, Fibers have
    //       changed things so that each thread has its own 'main' stack plus
    //       an arbitrary number of nested stacks (normally referenced via
    //       m_curr).  Also, there may be 'free-floating' stacks in the system,
    //       which are Fibers that are not currently executing on any specific
    //       thread but are still being processed and still contain valid
    //       roots.
    //
    //       To support all of this, the Context struct has been created to
    //       represent a stack range, and a global list of Context structs has
    //       been added to enable scanning of these stack ranges.  The lifetime
    //       (and presence in the Context list) of a thread's 'main' stack will
    //       be equivalent to the thread's lifetime.  So the Ccontext will be
    //       added to the list on thread entry, and removed from the list on
    //       thread exit (which is essentially the same as the presence of a
    //       Thread object in its own global list).  The lifetime of a Fiber's
    //       context, however, will be tied to the lifetime of the Fiber object
    //       itself, and Fibers are expected to add/remove their Context struct
    //       on construction/deletion.


    //
    // All use of the global thread lists/array should synchronize on this lock.
    //
    // Careful as the GC acquires this lock after the GC lock to suspend all
    // threads any GC usage with slock held can result in a deadlock through
    // lock order inversion.
    @property static Mutex slock() nothrow @nogc
    {
        return cast(Mutex)_slock.ptr;
    }

    @property static Mutex criticalRegionLock() nothrow @nogc
    {
        return cast(Mutex)_criticalRegionLock.ptr;
    }

    __gshared align(mutexAlign) void[mutexClassInstanceSize] _slock;
    __gshared align(mutexAlign) void[mutexClassInstanceSize] _criticalRegionLock;

    static void initLocks() @nogc
    {
        _slock[] = typeid(Mutex).initializer[];
        (cast(Mutex)_slock.ptr).__ctor();

        _criticalRegionLock[] = typeid(Mutex).initializer[];
        (cast(Mutex)_criticalRegionLock.ptr).__ctor();
    }

    static void termLocks() @nogc
    {
        (cast(Mutex)_slock.ptr).__dtor();
        (cast(Mutex)_criticalRegionLock.ptr).__dtor();
    }

    __gshared StackContext*  sm_cbeg;

    __gshared Thread    sm_tbeg;
    __gshared size_t    sm_tlen;

    // can't use core.internal.util.array in public code
    __gshared Thread* pAboutToStart;
    __gshared size_t nAboutToStart;

    //
    // Used for ordering threads in the global thread list.
    //
    Thread              prev;
    Thread              next;


    ///////////////////////////////////////////////////////////////////////////
    // Global Context List Operations
    ///////////////////////////////////////////////////////////////////////////


    //
    // Add a context to the global context list.
    //
    static void add( StackContext* c ) nothrow @nogc
    in
    {
        assert( c );
        assert( !c.next && !c.prev );
    }
    do
    {
        slock.lock_nothrow();
        scope(exit) slock.unlock_nothrow();
        assert(!suspendDepth); // must be 0 b/c it's only set with slock held

        if (sm_cbeg)
        {
            c.next = sm_cbeg;
            sm_cbeg.prev = c;
        }
        sm_cbeg = c;
    }

    //
    // Remove a context from the global context list.
    //
    // This assumes slock being acquired. This isn't done here to
    // avoid double locking when called from remove(Thread)
    static void remove( StackContext* c ) nothrow @nogc
    in
    {
        assert( c );
        assert( c.next || c.prev );
    }
    do
    {
        if ( c.prev )
            c.prev.next = c.next;
        if ( c.next )
            c.next.prev = c.prev;
        if ( sm_cbeg == c )
            sm_cbeg = c.next;
        // NOTE: Don't null out c.next or c.prev because opApply currently
        //       follows c.next after removing a node.  This could be easily
        //       addressed by simply returning the next node from this
        //       function, however, a context should never be re-added to the
        //       list anyway and having next and prev be non-null is a good way
        //       to ensure that.
    }


    ///////////////////////////////////////////////////////////////////////////
    // Global Thread List Operations
    ///////////////////////////////////////////////////////////////////////////


    //
    // Add a thread to the global thread list.
    //
    static void add( Thread t, bool rmAboutToStart = true ) nothrow @nogc
    in
    {
        assert( t );
        assert( !t.next && !t.prev );
    }
    do
    {
        slock.lock_nothrow();
        scope(exit) slock.unlock_nothrow();
        assert(t.isRunning); // check this with slock to ensure pthread_create already returned
        assert(!suspendDepth); // must be 0 b/c it's only set with slock held

        if (rmAboutToStart)
        {
            size_t idx = -1;
            foreach (i, thr; pAboutToStart[0 .. nAboutToStart])
            {
                if (thr is t)
                {
                    idx = i;
                    break;
                }
            }
            assert(idx != -1);
            import core.stdc.string : memmove;
            memmove(pAboutToStart + idx, pAboutToStart + idx + 1, Thread.sizeof * (nAboutToStart - idx - 1));
            pAboutToStart =
                cast(Thread*)realloc(pAboutToStart, Thread.sizeof * --nAboutToStart);
        }

        if (sm_tbeg)
        {
            t.next = sm_tbeg;
            sm_tbeg.prev = t;
        }
        sm_tbeg = t;
        ++sm_tlen;
    }


    //
    // Remove a thread from the global thread list.
    //
    static void remove( Thread t ) nothrow @nogc
    in
    {
        assert( t );
    }
    do
    {
        // Thread was already removed earlier, might happen b/c of thread_detachInstance
        if (!t.next && !t.prev && (sm_tbeg !is t))
            return;

        slock.lock_nothrow();
        {
            // NOTE: When a thread is removed from the global thread list its
            //       main context is invalid and should be removed as well.
            //       It is possible that t.m_curr could reference more
            //       than just the main context if the thread exited abnormally
            //       (if it was terminated), but we must assume that the user
            //       retains a reference to them and that they may be re-used
            //       elsewhere.  Therefore, it is the responsibility of any
            //       object that creates contexts to clean them up properly
            //       when it is done with them.
            remove( &t.m_main );

            if ( t.prev )
                t.prev.next = t.next;
            if ( t.next )
                t.next.prev = t.prev;
            if ( sm_tbeg is t )
                sm_tbeg = t.next;
            t.prev = t.next = null;
            --sm_tlen;
        }
        // NOTE: Don't null out t.next or t.prev because opApply currently
        //       follows t.next after removing a node.  This could be easily
        //       addressed by simply returning the next node from this
        //       function, however, a thread should never be re-added to the
        //       list anyway and having next and prev be non-null is a good way
        //       to ensure that.
        slock.unlock_nothrow();
    }
}

///
unittest
{
    class DerivedThread : Thread
    {
        this()
        {
            super(&run);
        }

    private:
        void run()
        {
            // Derived thread running.
        }
    }

    void threadFunc()
    {
        // Composed thread running.
    }

    // create and start instances of each type
    auto derived = new DerivedThread().start();
    auto composed = new Thread(&threadFunc).start();
    new Thread({
        // Codes to run in the newly created thread.
    }).start();
}

unittest
{
    int x = 0;

    new Thread(
    {
        x++;
    }).start().join();
    assert( x == 1 );
}


unittest
{
    enum MSG = "Test message.";
    string caughtMsg;

    try
    {
        new Thread(
        {
            throw new Exception( MSG );
        }).start().join();
        assert( false, "Expected rethrown exception." );
    }
    catch ( Throwable t )
    {
        assert( t.msg == MSG );
    }
}


///////////////////////////////////////////////////////////////////////////////
// GC Support Routines
///////////////////////////////////////////////////////////////////////////////

version (CoreDdoc)
{
    /**
     * Instruct the thread module, when initialized, to use a different set of
     * signals besides SIGUSR1 and SIGUSR2 for suspension and resumption of threads.
     * This function should be called at most once, prior to thread_init().
     * This function is Posix-only.
     */
    extern (C) void thread_setGCSignals(int suspendSignalNo, int resumeSignalNo) nothrow @nogc
    {
    }
}
else version (Posix)
{
    extern (C) void thread_setGCSignals(int suspendSignalNo, int resumeSignalNo) nothrow @nogc
    in
    {
        assert(suspendSignalNumber == 0);
        assert(resumeSignalNumber  == 0);
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
}

version (Posix)
{
    __gshared int suspendSignalNumber;
    __gshared int resumeSignalNumber;
}

/**
 * Initializes the thread module.  This function must be called by the
 * garbage collector on startup and before any other thread routines
 * are called.
 */
extern (C) void thread_init() @nogc
{
    // NOTE: If thread_init itself performs any allocations then the thread
    //       routines reserved for garbage collector use may be called while
    //       thread_init is being processed.  However, since no memory should
    //       exist to be scanned at this point, it is sufficient for these
    //       functions to detect the condition and return immediately.

    initLowlevelThreads();
    Thread.initLocks();

    // The Android VM runtime intercepts SIGUSR1 and apparently doesn't allow
    // its signal handler to run, so swap the two signals on Android, since
    // thread_resumeHandler does nothing.
    version (Android) thread_setGCSignals(SIGUSR2, SIGUSR1);

    version (Darwin)
    {
        // thread id different in forked child process
        static extern(C) void initChildAfterFork()
        {
            auto thisThread = Thread.getThis();
            thisThread.m_addr = pthread_self();
            assert( thisThread.m_addr != thisThread.m_addr.init );
            thisThread.m_tmach = pthread_mach_thread_np( thisThread.m_addr );
            assert( thisThread.m_tmach != thisThread.m_tmach.init );
       }
        pthread_atfork(null, null, &initChildAfterFork);
    }
    else version (Posix)
    {
        if ( suspendSignalNumber == 0 )
        {
            suspendSignalNumber = SIGUSR1;
        }

        if ( resumeSignalNumber == 0 )
        {
            resumeSignalNumber = SIGUSR2;
        }

        int         status;
        sigaction_t sigusr1 = void;
        sigaction_t sigusr2 = void;

        // This is a quick way to zero-initialize the structs without using
        // memset or creating a link dependency on their static initializer.
        (cast(byte*) &sigusr1)[0 .. sigaction_t.sizeof] = 0;
        (cast(byte*) &sigusr2)[0 .. sigaction_t.sizeof] = 0;

        // NOTE: SA_RESTART indicates that system calls should restart if they
        //       are interrupted by a signal, but this is not available on all
        //       Posix systems, even those that support multithreading.
        static if ( __traits( compiles, SA_RESTART ) )
            sigusr1.sa_flags = SA_RESTART;
        else
            sigusr1.sa_flags   = 0;
        sigusr1.sa_handler = &thread_suspendHandler;
        // NOTE: We want to ignore all signals while in this handler, so fill
        //       sa_mask to indicate this.
        status = sigfillset( &sigusr1.sa_mask );
        assert( status == 0 );

        // NOTE: Since resumeSignalNumber should only be issued for threads within the
        //       suspend handler, we don't want this signal to trigger a
        //       restart.
        sigusr2.sa_flags   = 0;
        sigusr2.sa_handler = &thread_resumeHandler;
        // NOTE: We want to ignore all signals while in this handler, so fill
        //       sa_mask to indicate this.
        status = sigfillset( &sigusr2.sa_mask );
        assert( status == 0 );

        status = sigaction( suspendSignalNumber, &sigusr1, null );
        assert( status == 0 );

        status = sigaction( resumeSignalNumber, &sigusr2, null );
        assert( status == 0 );

        status = sem_init( &suspendCount, 0, 0 );
        assert( status == 0 );
    }
    if (typeid(Thread).initializer.ptr)
        _mainThreadStore[] = typeid(Thread).initializer[];
    Thread.sm_main = attachThread((cast(Thread)_mainThreadStore.ptr).__ctor());
}

private __gshared align(Thread.alignof) void[__traits(classInstanceSize, Thread)] _mainThreadStore;

extern (C) void _d_monitordelete_nogc(Object h) @nogc;

/**
 * Terminates the thread module. No other thread routine may be called
 * afterwards.
 */
extern (C) void thread_term() @nogc
{
    assert(_mainThreadStore.ptr is cast(void*) Thread.sm_main);

    // destruct manually as object.destroy is not @nogc
    Thread.sm_main.__dtor();
    _d_monitordelete_nogc(Thread.sm_main);
    if (typeid(Thread).initializer.ptr)
        _mainThreadStore[] = typeid(Thread).initializer[];
    else
        (cast(ubyte[])_mainThreadStore)[] = 0;
    Thread.sm_main = null;

    assert(Thread.sm_tbeg && Thread.sm_tlen == 1);
    assert(!Thread.nAboutToStart);
    if (Thread.pAboutToStart) // in case realloc(p, 0) doesn't return null
    {
        free(Thread.pAboutToStart);
        Thread.pAboutToStart = null;
    }
    Thread.termLocks();
    termLowlevelThreads();
}


/**
 *
 */
extern (C) bool thread_isMainThread() nothrow @nogc
{
    return Thread.getThis() is Thread.sm_main;
}


/**
 * Registers the calling thread for use with the D Runtime.  If this routine
 * is called for a thread which is already registered, no action is performed.
 *
 * NOTE: This routine does not run thread-local static constructors when called.
 *       If full functionality as a D thread is desired, the following function
 *       must be called after thread_attachThis:
 *
 *       extern (C) void rt_moduleTlsCtor();
 */
extern (C) Thread thread_attachThis()
{
    if (auto t = Thread.getThis())
        return t;

    return attachThread(new Thread());
}

private Thread attachThread(Thread thisThread) @nogc
{
    StackContext* thisContext = &thisThread.m_main;
    assert( thisContext == thisThread.m_curr );

    version (Windows)
    {
        thisThread.m_addr  = GetCurrentThreadId();
        thisThread.m_hndl  = GetCurrentThreadHandle();
        thisContext.bstack = getStackBottom();
        thisContext.tstack = thisContext.bstack;
    }
    else version (Posix)
    {
        thisThread.m_addr  = pthread_self();
        thisContext.bstack = getStackBottom();
        thisContext.tstack = thisContext.bstack;

        atomicStore!(MemoryOrder.raw)(thisThread.m_isRunning, true);
    }
    thisThread.m_isDaemon = true;
    thisThread.m_tlsgcdata = rt_tlsgc_init();
    Thread.setThis( thisThread );

    version (Darwin)
    {
        thisThread.m_tmach = pthread_mach_thread_np( thisThread.m_addr );
        assert( thisThread.m_tmach != thisThread.m_tmach.init );
    }

    Thread.add( thisThread, false );
    Thread.add( thisContext );
    if ( Thread.sm_main !is null )
        multiThreadedFlag = true;
    return thisThread;
}


version (Windows)
{
    // NOTE: These calls are not safe on Posix systems that use signals to
    //       perform garbage collection.  The suspendHandler uses getThis()
    //       to get the thread handle so getThis() must be a simple call.
    //       Mutexes can't safely be acquired inside signal handlers, and
    //       even if they could, the mutex needed (Thread.slock) is held by
    //       thread_suspendAll().  So in short, these routines will remain
    //       Windows-specific.  If they are truly needed elsewhere, the
    //       suspendHandler will need a way to call a version of getThis()
    //       that only does the TLS lookup without the fancy fallback stuff.

    /// ditto
    extern (C) Thread thread_attachByAddr( ThreadID addr )
    {
        return thread_attachByAddrB( addr, getThreadStackBottom( addr ) );
    }


    /// ditto
    extern (C) Thread thread_attachByAddrB( ThreadID addr, void* bstack )
    {
        GC.disable(); scope(exit) GC.enable();

        if (auto t = thread_findByAddr(addr))
            return t;

        Thread        thisThread  = new Thread();
        StackContext* thisContext = &thisThread.m_main;
        assert( thisContext == thisThread.m_curr );

        thisThread.m_addr  = addr;
        thisContext.bstack = bstack;
        thisContext.tstack = thisContext.bstack;

        thisThread.m_isDaemon = true;

        if ( addr == GetCurrentThreadId() )
        {
            thisThread.m_hndl = GetCurrentThreadHandle();
            thisThread.m_tlsgcdata = rt_tlsgc_init();
            Thread.setThis( thisThread );
        }
        else
        {
            thisThread.m_hndl = OpenThreadHandle( addr );
            impersonate_thread(addr,
            {
                thisThread.m_tlsgcdata = rt_tlsgc_init();
                Thread.setThis( thisThread );
            });
        }

        Thread.add( thisThread, false );
        Thread.add( thisContext );
        if ( Thread.sm_main !is null )
            multiThreadedFlag = true;
        return thisThread;
    }
}


/**
 * Deregisters the calling thread from use with the runtime.  If this routine
 * is called for a thread which is not registered, the result is undefined.
 *
 * NOTE: This routine does not run thread-local static destructors when called.
 *       If full functionality as a D thread is desired, the following function
 *       must be called after thread_detachThis, particularly if the thread is
 *       being detached at some indeterminate time before program termination:
 *
 *       $(D extern(C) void rt_moduleTlsDtor();)
 */
extern (C) void thread_detachThis() nothrow @nogc
{
    if (auto t = Thread.getThis())
        Thread.remove(t);
}


/**
 * Deregisters the given thread from use with the runtime.  If this routine
 * is called for a thread which is not registered, the result is undefined.
 *
 * NOTE: This routine does not run thread-local static destructors when called.
 *       If full functionality as a D thread is desired, the following function
 *       must be called by the detached thread, particularly if the thread is
 *       being detached at some indeterminate time before program termination:
 *
 *       $(D extern(C) void rt_moduleTlsDtor();)
 */
extern (C) void thread_detachByAddr( ThreadID addr )
{
    if ( auto t = thread_findByAddr( addr ) )
        Thread.remove( t );
}


/// ditto
extern (C) void thread_detachInstance( Thread t ) nothrow @nogc
{
    Thread.remove( t );
}


unittest
{
    import core.sync.semaphore;
    auto sem = new Semaphore();

    auto t = new Thread(
    {
        sem.notify();
        Thread.sleep(100.msecs);
    }).start();

    sem.wait(); // thread cannot be detached while being started
    thread_detachInstance(t);
    foreach (t2; Thread)
        assert(t !is t2);
    t.join();
}


/**
 * Search the list of all threads for a thread with the given thread identifier.
 *
 * Params:
 *  addr = The thread identifier to search for.
 * Returns:
 *  The thread object associated with the thread identifier, null if not found.
 */
static Thread thread_findByAddr( ThreadID addr )
{
    Thread.slock.lock_nothrow();
    scope(exit) Thread.slock.unlock_nothrow();

    // also return just spawned thread so that
    // DLL_THREAD_ATTACH knows it's a D thread
    foreach (t; Thread.pAboutToStart[0 .. Thread.nAboutToStart])
        if (t.m_addr == addr)
            return t;

    foreach (t; Thread)
        if (t.m_addr == addr)
            return t;

    return null;
}


/**
 * Sets the current thread to a specific reference. Only to be used
 * when dealing with externally-created threads (in e.g. C code).
 * The primary use of this function is when Thread.getThis() must
 * return a sensible value in, for example, TLS destructors. In
 * other words, don't touch this unless you know what you're doing.
 *
 * Params:
 *  t = A reference to the current thread. May be null.
 */
extern (C) void thread_setThis(Thread t) nothrow @nogc
{
    Thread.setThis(t);
}


/**
 * Joins all non-daemon threads that are currently running.  This is done by
 * performing successive scans through the thread list until a scan consists
 * of only daemon threads.
 */
extern (C) void thread_joinAll()
{
 Lagain:
    Thread.slock.lock_nothrow();
    // wait for just spawned threads
    if (Thread.nAboutToStart)
    {
        Thread.slock.unlock_nothrow();
        Thread.yield();
        goto Lagain;
    }

    // join all non-daemon threads, the main thread is also a daemon
    auto t = Thread.sm_tbeg;
    while (t)
    {
        if (!t.isRunning)
        {
            auto tn = t.next;
            Thread.remove(t);
            t = tn;
        }
        else if (t.isDaemon)
        {
            t = t.next;
        }
        else
        {
            Thread.slock.unlock_nothrow();
            t.join(); // might rethrow
            goto Lagain; // must restart iteration b/c of unlock
        }
    }
    Thread.slock.unlock_nothrow();
}


/**
 * Performs intermediate shutdown of the thread module.
 */
shared static ~this()
{
    // NOTE: The functionality related to garbage collection must be minimally
    //       operable after this dtor completes.  Therefore, only minimal
    //       cleanup may occur.
    auto t = Thread.sm_tbeg;
    while (t)
    {
        auto tn = t.next;
        if (!t.isRunning)
            Thread.remove(t);
        t = tn;
    }
}


// Used for needLock below.
private __gshared bool multiThreadedFlag = false;

// Calls the given delegate, passing the current thread's stack pointer to it.
private void callWithStackShell(scope void delegate(void* sp) nothrow fn) nothrow
in
{
    assert(fn);
}
do
{
    // The purpose of the 'shell' is to ensure all the registers get
    // put on the stack so they'll be scanned. We only need to push
    // the callee-save registers.
    void *sp = void;
    version (GNU)
    {
        __builtin_unwind_init();
        sp = &sp;
    }
    else version (AsmX86_Posix)
    {
        size_t[3] regs = void;
        asm pure nothrow @nogc
        {
            mov [regs + 0 * 4], EBX;
            mov [regs + 1 * 4], ESI;
            mov [regs + 2 * 4], EDI;

            mov sp[EBP], ESP;
        }
    }
    else version (AsmX86_Windows)
    {
        size_t[3] regs = void;
        asm pure nothrow @nogc
        {
            mov [regs + 0 * 4], EBX;
            mov [regs + 1 * 4], ESI;
            mov [regs + 2 * 4], EDI;

            mov sp[EBP], ESP;
        }
    }
    else version (AsmX86_64_Posix)
    {
        size_t[5] regs = void;
        asm pure nothrow @nogc
        {
            mov [regs + 0 * 8], RBX;
            mov [regs + 1 * 8], R12;
            mov [regs + 2 * 8], R13;
            mov [regs + 3 * 8], R14;
            mov [regs + 4 * 8], R15;

            mov sp[RBP], RSP;
        }
    }
    else version (AsmX86_64_Windows)
    {
        size_t[7] regs = void;
        asm pure nothrow @nogc
        {
            mov [regs + 0 * 8], RBX;
            mov [regs + 1 * 8], RSI;
            mov [regs + 2 * 8], RDI;
            mov [regs + 3 * 8], R12;
            mov [regs + 4 * 8], R13;
            mov [regs + 5 * 8], R14;
            mov [regs + 6 * 8], R15;

            mov sp[RBP], RSP;
        }
    }
    else
    {
        static assert(false, "Architecture not supported.");
    }

    fn(sp);
}

// Used for suspendAll/resumeAll below.
private __gshared uint suspendDepth = 0;

/**
 * Suspend the specified thread and load stack and register information for
 * use by thread_scanAll.  If the supplied thread is the calling thread,
 * stack and register information will be loaded but the thread will not
 * be suspended.  If the suspend operation fails and the thread is not
 * running then it will be removed from the global thread list, otherwise
 * an exception will be thrown.
 *
 * Params:
 *  t = The thread to suspend.
 *
 * Throws:
 *  ThreadError if the suspend operation fails for a running thread.
 * Returns:
 *  Whether the thread is now suspended (true) or terminated (false).
 */
private bool suspend( Thread t ) nothrow
{
    Duration waittime = dur!"usecs"(10);
 Lagain:
    if (!t.isRunning)
    {
        Thread.remove(t);
        return false;
    }
    else if (t.m_isInCriticalRegion)
    {
        Thread.criticalRegionLock.unlock_nothrow();
        Thread.sleep(waittime);
        if (waittime < dur!"msecs"(10)) waittime *= 2;
        Thread.criticalRegionLock.lock_nothrow();
        goto Lagain;
    }

    version (Windows)
    {
        if ( t.m_addr != GetCurrentThreadId() && SuspendThread( t.m_hndl ) == 0xFFFFFFFF )
        {
            if ( !t.isRunning )
            {
                Thread.remove( t );
                return false;
            }
            onThreadError( "Unable to suspend thread" );
        }

        CONTEXT context = void;
        context.ContextFlags = CONTEXT_INTEGER | CONTEXT_CONTROL;

        if ( !GetThreadContext( t.m_hndl, &context ) )
            onThreadError( "Unable to load thread context" );
        version (X86)
        {
            if ( !t.m_lock )
                t.m_curr.tstack = cast(void*) context.Esp;
            // eax,ebx,ecx,edx,edi,esi,ebp,esp
            t.m_reg[0] = context.Eax;
            t.m_reg[1] = context.Ebx;
            t.m_reg[2] = context.Ecx;
            t.m_reg[3] = context.Edx;
            t.m_reg[4] = context.Edi;
            t.m_reg[5] = context.Esi;
            t.m_reg[6] = context.Ebp;
            t.m_reg[7] = context.Esp;
        }
        else version (X86_64)
        {
            if ( !t.m_lock )
                t.m_curr.tstack = cast(void*) context.Rsp;
            // rax,rbx,rcx,rdx,rdi,rsi,rbp,rsp
            t.m_reg[0] = context.Rax;
            t.m_reg[1] = context.Rbx;
            t.m_reg[2] = context.Rcx;
            t.m_reg[3] = context.Rdx;
            t.m_reg[4] = context.Rdi;
            t.m_reg[5] = context.Rsi;
            t.m_reg[6] = context.Rbp;
            t.m_reg[7] = context.Rsp;
            // r8,r9,r10,r11,r12,r13,r14,r15
            t.m_reg[8]  = context.R8;
            t.m_reg[9]  = context.R9;
            t.m_reg[10] = context.R10;
            t.m_reg[11] = context.R11;
            t.m_reg[12] = context.R12;
            t.m_reg[13] = context.R13;
            t.m_reg[14] = context.R14;
            t.m_reg[15] = context.R15;
        }
        else
        {
            static assert(false, "Architecture not supported." );
        }
    }
    else version (Darwin)
    {
        if ( t.m_addr != pthread_self() && thread_suspend( t.m_tmach ) != KERN_SUCCESS )
        {
            if ( !t.isRunning )
            {
                Thread.remove( t );
                return false;
            }
            onThreadError( "Unable to suspend thread" );
        }

        version (X86)
        {
            x86_thread_state32_t    state = void;
            mach_msg_type_number_t  count = x86_THREAD_STATE32_COUNT;

            if ( thread_get_state( t.m_tmach, x86_THREAD_STATE32, &state, &count ) != KERN_SUCCESS )
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

            if ( thread_get_state( t.m_tmach, x86_THREAD_STATE64, &state, &count ) != KERN_SUCCESS )
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

            if (thread_get_state(t.m_tmach, ARM_THREAD_STATE64, &state, &count) != KERN_SUCCESS)
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
            if (thread_get_state(t.m_tmach, ARM_THREAD_STATE, &state, &count) != KERN_SUCCESS)
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
        else
        {
            static assert(false, "Architecture not supported." );
        }
    }
    else version (Posix)
    {
        if ( t.m_addr != pthread_self() )
        {
            if ( pthread_kill( t.m_addr, suspendSignalNumber ) != 0 )
            {
                if ( !t.isRunning )
                {
                    Thread.remove( t );
                    return false;
                }
                onThreadError( "Unable to suspend thread" );
            }
        }
        else if ( !t.m_lock )
        {
            t.m_curr.tstack = getStackTop();
        }
    }
    return true;
}

/**
 * Suspend all threads but the calling thread for "stop the world" garbage
 * collection runs.  This function may be called multiple times, and must
 * be followed by a matching number of calls to thread_resumeAll before
 * processing is resumed.
 *
 * Throws:
 *  ThreadError if the suspend operation fails for a running thread.
 */
extern (C) void thread_suspendAll() nothrow
{
    // NOTE: We've got an odd chicken & egg problem here, because while the GC
    //       is required to call thread_init before calling any other thread
    //       routines, thread_init may allocate memory which could in turn
    //       trigger a collection.  Thus, thread_suspendAll, thread_scanAll,
    //       and thread_resumeAll must be callable before thread_init
    //       completes, with the assumption that no other GC memory has yet
    //       been allocated by the system, and thus there is no risk of losing
    //       data if the global thread list is empty.  The check of
    //       Thread.sm_tbeg below is done to ensure thread_init has completed,
    //       and therefore that calling Thread.getThis will not result in an
    //       error.  For the short time when Thread.sm_tbeg is null, there is
    //       no reason not to simply call the multithreaded code below, with
    //       the expectation that the foreach loop will never be entered.
    if ( !multiThreadedFlag && Thread.sm_tbeg )
    {
        if ( ++suspendDepth == 1 )
            suspend( Thread.getThis() );

        return;
    }

    Thread.slock.lock_nothrow();
    {
        if ( ++suspendDepth > 1 )
            return;

        Thread.criticalRegionLock.lock_nothrow();
        scope (exit) Thread.criticalRegionLock.unlock_nothrow();
        size_t cnt;
        auto t = Thread.sm_tbeg;
        while (t)
        {
            auto tn = t.next;
            if (suspend(t))
                ++cnt;
            t = tn;
        }

        version (Darwin)
        {}
        else version (Posix)
        {
            // subtract own thread
            assert(cnt >= 1);
            --cnt;
        Lagain:
            // wait for semaphore notifications
            for (; cnt; --cnt)
            {
                while (sem_wait(&suspendCount) != 0)
                {
                    if (errno != EINTR)
                        onThreadError("Unable to wait for semaphore");
                    errno = 0;
                }
            }
            version (FreeBSD)
            {
                // avoid deadlocks, see Issue 13416
                t = Thread.sm_tbeg;
                while (t)
                {
                    auto tn = t.next;
                    if (t.m_suspendagain && suspend(t))
                        ++cnt;
                    t = tn;
                }
                if (cnt)
                    goto Lagain;
             }
        }
    }
}

/**
 * Resume the specified thread and unload stack and register information.
 * If the supplied thread is the calling thread, stack and register
 * information will be unloaded but the thread will not be resumed.  If
 * the resume operation fails and the thread is not running then it will
 * be removed from the global thread list, otherwise an exception will be
 * thrown.
 *
 * Params:
 *  t = The thread to resume.
 *
 * Throws:
 *  ThreadError if the resume fails for a running thread.
 */
private void resume( Thread t ) nothrow
{
    version (Windows)
    {
        if ( t.m_addr != GetCurrentThreadId() && ResumeThread( t.m_hndl ) == 0xFFFFFFFF )
        {
            if ( !t.isRunning )
            {
                Thread.remove( t );
                return;
            }
            onThreadError( "Unable to resume thread" );
        }

        if ( !t.m_lock )
            t.m_curr.tstack = t.m_curr.bstack;
        t.m_reg[0 .. $] = 0;
    }
    else version (Darwin)
    {
        if ( t.m_addr != pthread_self() && thread_resume( t.m_tmach ) != KERN_SUCCESS )
        {
            if ( !t.isRunning )
            {
                Thread.remove( t );
                return;
            }
            onThreadError( "Unable to resume thread" );
        }

        if ( !t.m_lock )
            t.m_curr.tstack = t.m_curr.bstack;
        t.m_reg[0 .. $] = 0;
    }
    else version (Posix)
    {
        if ( t.m_addr != pthread_self() )
        {
            if ( pthread_kill( t.m_addr, resumeSignalNumber ) != 0 )
            {
                if ( !t.isRunning )
                {
                    Thread.remove( t );
                    return;
                }
                onThreadError( "Unable to resume thread" );
            }
        }
        else if ( !t.m_lock )
        {
            t.m_curr.tstack = t.m_curr.bstack;
        }
    }
}

/**
 * Resume all threads but the calling thread for "stop the world" garbage
 * collection runs.  This function must be called once for each preceding
 * call to thread_suspendAll before the threads are actually resumed.
 *
 * In:
 *  This routine must be preceded by a call to thread_suspendAll.
 *
 * Throws:
 *  ThreadError if the resume operation fails for a running thread.
 */
extern (C) void thread_resumeAll() nothrow
in
{
    assert( suspendDepth > 0 );
}
do
{
    // NOTE: See thread_suspendAll for the logic behind this.
    if ( !multiThreadedFlag && Thread.sm_tbeg )
    {
        if ( --suspendDepth == 0 )
            resume( Thread.getThis() );
        return;
    }

    scope(exit) Thread.slock.unlock_nothrow();
    {
        if ( --suspendDepth > 0 )
            return;

        for ( Thread t = Thread.sm_tbeg; t; t = t.next )
        {
            // NOTE: We do not need to care about critical regions at all
            //       here. thread_suspendAll takes care of everything.
            resume( t );
        }
    }
}

/**
 * Indicates the kind of scan being performed by $(D thread_scanAllType).
 */
enum ScanType
{
    stack, /// The stack and/or registers are being scanned.
    tls, /// TLS data is being scanned.
}

alias ScanAllThreadsFn = void delegate(void*, void*) nothrow; /// The scanning function.
alias ScanAllThreadsTypeFn = void delegate(ScanType, void*, void*) nothrow; /// ditto

/**
 * The main entry point for garbage collection.  The supplied delegate
 * will be passed ranges representing both stack and register values.
 *
 * Params:
 *  scan        = The scanner function.  It should scan from p1 through p2 - 1.
 *
 * In:
 *  This routine must be preceded by a call to thread_suspendAll.
 */
extern (C) void thread_scanAllType( scope ScanAllThreadsTypeFn scan ) nothrow
in
{
    assert( suspendDepth > 0 );
}
do
{
    callWithStackShell(sp => scanAllTypeImpl(scan, sp));
}


private void scanAllTypeImpl( scope ScanAllThreadsTypeFn scan, void* curStackTop ) nothrow
{
    Thread  thisThread  = null;
    void*   oldStackTop = null;

    if ( Thread.sm_tbeg )
    {
        thisThread  = Thread.getThis();
        if ( !thisThread.m_lock )
        {
            oldStackTop = thisThread.m_curr.tstack;
            thisThread.m_curr.tstack = curStackTop;
        }
    }

    scope( exit )
    {
        if ( Thread.sm_tbeg )
        {
            if ( !thisThread.m_lock )
            {
                thisThread.m_curr.tstack = oldStackTop;
            }
        }
    }

    // NOTE: Synchronizing on Thread.slock is not needed because this
    //       function may only be called after all other threads have
    //       been suspended from within the same lock.
    if (Thread.nAboutToStart)
        scan(ScanType.stack, Thread.pAboutToStart, Thread.pAboutToStart + Thread.nAboutToStart);

    for ( StackContext* c = Thread.sm_cbeg; c; c = c.next )
    {
        version (StackGrowsDown)
        {
            // NOTE: We can't index past the bottom of the stack
            //       so don't do the "+1" for StackGrowsDown.
            if ( c.tstack && c.tstack < c.bstack )
                scan( ScanType.stack, c.tstack, c.bstack );
        }
        else
        {
            if ( c.bstack && c.bstack < c.tstack )
                scan( ScanType.stack, c.bstack, c.tstack + 1 );
        }
    }

    for ( Thread t = Thread.sm_tbeg; t; t = t.next )
    {
        version (Windows)
        {
            // Ideally, we'd pass ScanType.regs or something like that, but this
            // would make portability annoying because it only makes sense on Windows.
            scan( ScanType.stack, t.m_reg.ptr, t.m_reg.ptr + t.m_reg.length );
        }

        if (t.m_tlsgcdata !is null)
            rt_tlsgc_scan(t.m_tlsgcdata, (p1, p2) => scan(ScanType.tls, p1, p2));
    }
}

/**
 * The main entry point for garbage collection.  The supplied delegate
 * will be passed ranges representing both stack and register values.
 *
 * Params:
 *  scan        = The scanner function.  It should scan from p1 through p2 - 1.
 *
 * In:
 *  This routine must be preceded by a call to thread_suspendAll.
 */
extern (C) void thread_scanAll( scope ScanAllThreadsFn scan ) nothrow
{
    thread_scanAllType((type, p1, p2) => scan(p1, p2));
}


/**
 * Signals that the code following this call is a critical region. Any code in
 * this region must finish running before the calling thread can be suspended
 * by a call to thread_suspendAll.
 *
 * This function is, in particular, meant to help maintain garbage collector
 * invariants when a lock is not used.
 *
 * A critical region is exited with thread_exitCriticalRegion.
 *
 * $(RED Warning):
 * Using critical regions is extremely error-prone. For instance, using locks
 * inside a critical region can easily result in a deadlock when another thread
 * holding the lock already got suspended.
 *
 * The term and concept of a 'critical region' comes from
 * $(LINK2 https://github.com/mono/mono/blob/521f4a198e442573c400835ef19bbb36b60b0ebb/mono/metadata/sgen-gc.h#L925, Mono's SGen garbage collector).
 *
 * In:
 *  The calling thread must be attached to the runtime.
 */
extern (C) void thread_enterCriticalRegion() @nogc
in
{
    assert(Thread.getThis());
}
do
{
    synchronized (Thread.criticalRegionLock)
        Thread.getThis().m_isInCriticalRegion = true;
}


/**
 * Signals that the calling thread is no longer in a critical region. Following
 * a call to this function, the thread can once again be suspended.
 *
 * In:
 *  The calling thread must be attached to the runtime.
 */
extern (C) void thread_exitCriticalRegion() @nogc
in
{
    assert(Thread.getThis());
}
do
{
    synchronized (Thread.criticalRegionLock)
        Thread.getThis().m_isInCriticalRegion = false;
}


/**
 * Returns true if the current thread is in a critical region; otherwise, false.
 *
 * In:
 *  The calling thread must be attached to the runtime.
 */
extern (C) bool thread_inCriticalRegion() @nogc
in
{
    assert(Thread.getThis());
}
do
{
    synchronized (Thread.criticalRegionLock)
        return Thread.getThis().m_isInCriticalRegion;
}


/**
* A callback for thread errors in D during collections. Since an allocation is not possible
*  a preallocated ThreadError will be used as the Error instance
*
* Returns:
*  never returns
* Throws:
*  ThreadError.
*/
private void onThreadError(string msg) nothrow @nogc
{
    __gshared ThreadError error = new ThreadError(null);
    error.msg = msg;
    error.next = null;
    import core.exception : SuppressTraceInfo;
    error.info = SuppressTraceInfo.instance;
    throw error;
}

version (Posix)
private size_t adjustStackSize(size_t sz) nothrow @nogc
{
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

    // stack size must be a multiple of PAGESIZE
    sz = ((sz + PAGESIZE - 1) & ~(PAGESIZE - 1));

    return sz;
}

unittest
{
    assert(!thread_inCriticalRegion());

    {
        thread_enterCriticalRegion();

        scope (exit)
            thread_exitCriticalRegion();

        assert(thread_inCriticalRegion());
    }

    assert(!thread_inCriticalRegion());
}

unittest
{
    // NOTE: This entire test is based on the assumption that no
    //       memory is allocated after the child thread is
    //       started. If an allocation happens, a collection could
    //       trigger, which would cause the synchronization below
    //       to cause a deadlock.
    // NOTE: DO NOT USE LOCKS IN CRITICAL REGIONS IN NORMAL CODE.

    import core.sync.semaphore;

    auto sema = new Semaphore(),
         semb = new Semaphore();

    auto thr = new Thread(
    {
        thread_enterCriticalRegion();
        assert(thread_inCriticalRegion());
        sema.notify();

        semb.wait();
        assert(thread_inCriticalRegion());

        thread_exitCriticalRegion();
        assert(!thread_inCriticalRegion());
        sema.notify();

        semb.wait();
        assert(!thread_inCriticalRegion());
    });

    thr.start();

    sema.wait();
    synchronized (Thread.criticalRegionLock)
        assert(thr.m_isInCriticalRegion);
    semb.notify();

    sema.wait();
    synchronized (Thread.criticalRegionLock)
        assert(!thr.m_isInCriticalRegion);
    semb.notify();

    thr.join();
}

unittest
{
    import core.sync.semaphore;

    shared bool inCriticalRegion;
    auto sema = new Semaphore(),
         semb = new Semaphore();

    auto thr = new Thread(
    {
        thread_enterCriticalRegion();
        inCriticalRegion = true;
        sema.notify();
        semb.wait();

        Thread.sleep(dur!"msecs"(1));
        inCriticalRegion = false;
        thread_exitCriticalRegion();
    });
    thr.start();

    sema.wait();
    assert(inCriticalRegion);
    semb.notify();

    thread_suspendAll();
    assert(!inCriticalRegion);
    thread_resumeAll();
}

/**
 * Indicates whether an address has been marked by the GC.
 */
enum IsMarked : int
{
         no, /// Address is not marked.
        yes, /// Address is marked.
    unknown, /// Address is not managed by the GC.
}

alias IsMarkedDg = int delegate( void* addr ) nothrow; /// The isMarked callback function.

/**
 * This routine allows the runtime to process any special per-thread handling
 * for the GC.  This is needed for taking into account any memory that is
 * referenced by non-scanned pointers but is about to be freed.  That currently
 * means the array append cache.
 *
 * Params:
 *  isMarked = The function used to check if $(D addr) is marked.
 *
 * In:
 *  This routine must be called just prior to resuming all threads.
 */
extern(C) void thread_processGCMarks( scope IsMarkedDg isMarked ) nothrow
{
    for ( Thread t = Thread.sm_tbeg; t; t = t.next )
    {
        /* Can be null if collection was triggered between adding a
         * thread and calling rt_tlsgc_init.
         */
        if (t.m_tlsgcdata !is null)
            rt_tlsgc_processGCMarks(t.m_tlsgcdata, isMarked);
    }
}


extern (C) @nogc nothrow
{
    version (CRuntime_Glibc)  version = PThread_Getattr_NP;
    version (CRuntime_Bionic) version = PThread_Getattr_NP;
    version (CRuntime_Musl)   version = PThread_Getattr_NP;
    version (CRuntime_UClibc) version = PThread_Getattr_NP;

    version (FreeBSD)         version = PThread_Attr_Get_NP;
    version (NetBSD)          version = PThread_Attr_Get_NP;
    version (DragonFlyBSD)    version = PThread_Attr_Get_NP;

    version (PThread_Getattr_NP)  int pthread_getattr_np(pthread_t thread, pthread_attr_t* attr);
    version (PThread_Attr_Get_NP) int pthread_attr_get_np(pthread_t thread, pthread_attr_t* attr);
    version (Solaris) int thr_stksegment(stack_t* stk);
    version (OpenBSD) int pthread_stackseg_np(pthread_t thread, stack_t* sinfo);
}


package(core.thread) void* getStackTop() nothrow @nogc
{
    version (D_InlineAsm_X86)
        asm pure nothrow @nogc { naked; mov EAX, ESP; ret; }
    else version (D_InlineAsm_X86_64)
        asm pure nothrow @nogc { naked; mov RAX, RSP; ret; }
    else version (GNU)
        return __builtin_frame_address(0);
    else
        static assert(false, "Architecture not supported.");
}


package(core.thread) void* getStackBottom() nothrow @nogc
{
    version (Windows)
    {
        version (D_InlineAsm_X86)
            asm pure nothrow @nogc { naked; mov EAX, FS:4; ret; }
        else version (D_InlineAsm_X86_64)
            asm pure nothrow @nogc
            {    naked;
                 mov RAX, 8;
                 mov RAX, GS:[RAX];
                 ret;
            }
        else
            static assert(false, "Architecture not supported.");
    }
    else version (Darwin)
    {
        import core.sys.darwin.pthread;
        return pthread_get_stackaddr_np(pthread_self());
    }
    else version (PThread_Getattr_NP)
    {
        pthread_attr_t attr;
        void* addr; size_t size;

        pthread_attr_init(&attr);
        pthread_getattr_np(pthread_self(), &attr);
        pthread_attr_getstack(&attr, &addr, &size);
        pthread_attr_destroy(&attr);
        version (StackGrowsDown)
            addr += size;
        return addr;
    }
    else version (PThread_Attr_Get_NP)
    {
        pthread_attr_t attr;
        void* addr; size_t size;

        pthread_attr_init(&attr);
        pthread_attr_get_np(pthread_self(), &attr);
        pthread_attr_getstack(&attr, &addr, &size);
        pthread_attr_destroy(&attr);
        version (StackGrowsDown)
            addr += size;
        return addr;
    }
    else version (OpenBSD)
    {
        stack_t stk;

        pthread_stackseg_np(pthread_self(), &stk);
        return stk.ss_sp;
    }
    else version (Solaris)
    {
        stack_t stk;

        thr_stksegment(&stk);
        return stk.ss_sp;
    }
    else
        static assert(false, "Platform not supported.");
}


/**
 * Returns the stack top of the currently active stack within the calling
 * thread.
 *
 * In:
 *  The calling thread must be attached to the runtime.
 *
 * Returns:
 *  The address of the stack top.
 */
extern (C) void* thread_stackTop() nothrow @nogc
in
{
    // Not strictly required, but it gives us more flexibility.
    assert(Thread.getThis());
}
do
{
    return getStackTop();
}


/**
 * Returns the stack bottom of the currently active stack within the calling
 * thread.
 *
 * In:
 *  The calling thread must be attached to the runtime.
 *
 * Returns:
 *  The address of the stack bottom.
 */
extern (C) void* thread_stackBottom() nothrow @nogc
in
{
    assert(Thread.getThis());
}
do
{
    return Thread.getThis().topContext().bstack;
}


///////////////////////////////////////////////////////////////////////////////
// Thread Group
///////////////////////////////////////////////////////////////////////////////


/**
 * This class is intended to simplify certain common programming techniques.
 */
class ThreadGroup
{
    /**
     * Creates and starts a new Thread object that executes fn and adds it to
     * the list of tracked threads.
     *
     * Params:
     *  fn = The thread function.
     *
     * Returns:
     *  A reference to the newly created thread.
     */
    final Thread create( void function() fn )
    {
        Thread t = new Thread( fn ).start();

        synchronized( this )
        {
            m_all[t] = t;
        }
        return t;
    }


    /**
     * Creates and starts a new Thread object that executes dg and adds it to
     * the list of tracked threads.
     *
     * Params:
     *  dg = The thread function.
     *
     * Returns:
     *  A reference to the newly created thread.
     */
    final Thread create( void delegate() dg )
    {
        Thread t = new Thread( dg ).start();

        synchronized( this )
        {
            m_all[t] = t;
        }
        return t;
    }


    /**
     * Add t to the list of tracked threads if it is not already being tracked.
     *
     * Params:
     *  t = The thread to add.
     *
     * In:
     *  t must not be null.
     */
    final void add( Thread t )
    in
    {
        assert( t );
    }
    do
    {
        synchronized( this )
        {
            m_all[t] = t;
        }
    }


    /**
     * Removes t from the list of tracked threads.  No operation will be
     * performed if t is not currently being tracked by this object.
     *
     * Params:
     *  t = The thread to remove.
     *
     * In:
     *  t must not be null.
     */
    final void remove( Thread t )
    in
    {
        assert( t );
    }
    do
    {
        synchronized( this )
        {
            m_all.remove( t );
        }
    }


    /**
     * Operates on all threads currently tracked by this object.
     */
    final int opApply( scope int delegate( ref Thread ) dg )
    {
        synchronized( this )
        {
            int ret = 0;

            // NOTE: This loop relies on the knowledge that m_all uses the
            //       Thread object for both the key and the mapped value.
            foreach ( Thread t; m_all.keys )
            {
                ret = dg( t );
                if ( ret )
                    break;
            }
            return ret;
        }
    }


    /**
     * Iteratively joins all tracked threads.  This function will block add,
     * remove, and opApply until it completes.
     *
     * Params:
     *  rethrow = Rethrow any unhandled exception which may have caused the
     *            current thread to terminate.
     *
     * Throws:
     *  Any exception not handled by the joined threads.
     */
    final void joinAll( bool rethrow = true )
    {
        synchronized( this )
        {
            // NOTE: This loop relies on the knowledge that m_all uses the
            //       Thread object for both the key and the mapped value.
            foreach ( Thread t; m_all.keys )
            {
                t.join( rethrow );
            }
        }
    }


private:
    Thread[Thread]  m_all;
}

// regression test for Issue 13416
version (FreeBSD) unittest
{
    static void loop()
    {
        pthread_attr_t attr;
        pthread_attr_init(&attr);
        auto thr = pthread_self();
        foreach (i; 0 .. 50)
            pthread_attr_get_np(thr, &attr);
        pthread_attr_destroy(&attr);
    }

    auto thr = new Thread(&loop).start();
    foreach (i; 0 .. 50)
    {
        thread_suspendAll();
        thread_resumeAll();
    }
    thr.join();
}

version (DragonFlyBSD) unittest
{
    static void loop()
    {
        pthread_attr_t attr;
        pthread_attr_init(&attr);
        auto thr = pthread_self();
        foreach (i; 0 .. 50)
            pthread_attr_get_np(thr, &attr);
        pthread_attr_destroy(&attr);
    }

    auto thr = new Thread(&loop).start();
    foreach (i; 0 .. 50)
    {
        thread_suspendAll();
        thread_resumeAll();
    }
    thr.join();
}

unittest
{
    // use >PAGESIZE to avoid stack overflow (e.g. in an syscall)
    auto thr = new Thread(function{}, 4096 + 1).start();
    thr.join();
}

/**
 * Represents the ID of a thread, as returned by $(D Thread.)$(LREF id).
 * The exact type varies from platform to platform.
 */
version (Windows)
    alias ThreadID = uint;
else
version (Posix)
    alias ThreadID = pthread_t;

///////////////////////////////////////////////////////////////////////////////
// lowlovel threading support
private
{
    struct ll_ThreadData
    {
        ThreadID tid;
        version (Windows)
            void delegate() nothrow cbDllUnload;
    }

    __gshared size_t ll_nThreads;
    __gshared ll_ThreadData* ll_pThreads;

    __gshared align(mutexAlign) void[mutexClassInstanceSize] ll_lock;

    @property Mutex lowlevelLock() nothrow @nogc
    {
        return cast(Mutex)ll_lock.ptr;
    }

    void initLowlevelThreads() @nogc
    {
        ll_lock[] = typeid(Mutex).initializer[];
        lowlevelLock.__ctor();
    }

    void termLowlevelThreads() @nogc
    {
        lowlevelLock.__dtor();
    }

    void ll_removeThread(ThreadID tid) nothrow @nogc
    {
        lowlevelLock.lock_nothrow();
        scope(exit) lowlevelLock.unlock_nothrow();

        foreach (i; 0 .. ll_nThreads)
        {
            if (tid is ll_pThreads[i].tid)
            {
                import core.stdc.string : memmove;
                memmove(ll_pThreads + i, ll_pThreads + i + 1, ll_ThreadData.sizeof * (ll_nThreads - i - 1));
                --ll_nThreads;
                // no need to minimize, next add will do
                break;
            }
        }
    }

    version (Windows):
    // If the runtime is dynamically loaded as a DLL, there is a problem with
    // threads still running when the DLL is supposed to be unloaded:
    //
    // - with the VC runtime starting with VS2015 (i.e. using the Universal CRT)
    //   a thread created with _beginthreadex increments the DLL reference count
    //   and decrements it when done, so that the DLL is no longer unloaded unless
    //   all the threads have terminated. With the DLL reference count held up
    //   by a thread that is only stopped by a signal from a static destructor or
    //   the termination of the runtime will cause the DLL to never be unloaded.
    //
    // - with the DigitalMars runtime and VC runtime up to VS2013, the thread
    //   continues to run, but crashes once the DLL is unloaded from memory as
    //   the code memory is no longer accessible. Stopping the threads is not possible
    //   from within the runtime termination as it is invoked from
    //   DllMain(DLL_PROCESS_DETACH) holding a lock that prevents threads from
    //   terminating.
    //
    // Solution: start a watchdog thread that keeps the DLL reference count above 0 and
    // checks it periodically. If it is equal to 1 (plus the number of started threads), no
    // external references to the DLL exist anymore, threads can be stopped
    // and runtime termination and DLL unload can be invoked via FreeLibraryAndExitThread.
    // Note: runtime termination is then performed by a different thread than at startup.
    //
    // Note: if the DLL is never unloaded, process termination kills all threads
    // and signals their handles before unconditionally calling DllMain(DLL_PROCESS_DETACH).

    import core.sys.windows.winbase : FreeLibraryAndExitThread, GetModuleHandleExW,
        GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS, GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT;
    import core.sys.windows.windef : HMODULE;
    import core.sys.windows.dll : dll_getRefCount;

    version (CRuntime_Microsoft)
        extern(C) extern __gshared ubyte msvcUsesUCRT; // from rt/msvc.c

    /// set during termination of a DLL on Windows, i.e. while executing DllMain(DLL_PROCESS_DETACH)
    public __gshared bool thread_DLLProcessDetaching;

    __gshared HMODULE ll_dllModule;
    __gshared ThreadID ll_dllMonitorThread;

    int ll_countLowLevelThreadsWithDLLUnloadCallback() nothrow
    {
        lowlevelLock.lock_nothrow();
        scope(exit) lowlevelLock.unlock_nothrow();

        int cnt = 0;
        foreach (i; 0 .. ll_nThreads)
            if (ll_pThreads[i].cbDllUnload)
                cnt++;
        return cnt;
    }

    bool ll_dllHasExternalReferences() nothrow
    {
        version (CRuntime_DigitalMars)
            enum internalReferences = 1; // only the watchdog thread
        else
            int internalReferences =  msvcUsesUCRT ? 1 + ll_countLowLevelThreadsWithDLLUnloadCallback() : 1;

        int refcnt = dll_getRefCount(ll_dllModule);
        return refcnt > internalReferences;
    }

    private void monitorDLLRefCnt() nothrow
    {
        // this thread keeps the DLL alive until all external references are gone
        while (ll_dllHasExternalReferences())
        {
            Thread.sleep(100.msecs);
        }

        // the current thread will be terminated below
        ll_removeThread(GetCurrentThreadId());

        for (;;)
        {
            ThreadID tid;
            void delegate() nothrow cbDllUnload;
            {
                lowlevelLock.lock_nothrow();
                scope(exit) lowlevelLock.unlock_nothrow();

                foreach (i; 0 .. ll_nThreads)
                    if (ll_pThreads[i].cbDllUnload)
                    {
                        cbDllUnload = ll_pThreads[i].cbDllUnload;
                        tid = ll_pThreads[0].tid;
                    }
            }
            if (!cbDllUnload)
                break;
            cbDllUnload();
            assert(!findLowLevelThread(tid));
        }

        FreeLibraryAndExitThread(ll_dllModule, 0);
    }

    int ll_getDLLRefCount() nothrow @nogc
    {
        if (!ll_dllModule &&
            !GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                                cast(const(wchar)*) &ll_getDLLRefCount, &ll_dllModule))
            return -1;
        return dll_getRefCount(ll_dllModule);
    }

    bool ll_startDLLUnloadThread() nothrow @nogc
    {
        int refcnt = ll_getDLLRefCount();
        if (refcnt < 0)
            return false; // not a dynamically loaded DLL

        if (ll_dllMonitorThread !is ThreadID.init)
            return true;

        // if a thread is created from a DLL, the MS runtime (starting with VC2015) increments the DLL reference count
        // to avoid the DLL being unloaded while the thread is still running. Mimick this behavior here for all
        // runtimes not doing this
        version (CRuntime_DigitalMars)
            enum needRef = true;
        else
            bool needRef = !msvcUsesUCRT;

        if (needRef)
        {
            HMODULE hmod;
            GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS, cast(const(wchar)*) &ll_getDLLRefCount, &hmod);
        }

        ll_dllMonitorThread = createLowLevelThread(() { monitorDLLRefCnt(); });
        return ll_dllMonitorThread != ThreadID.init;
    }
}

/**
 * Create a thread not under control of the runtime, i.e. TLS module constructors are
 * not run and the GC does not suspend it during a collection.
 *
 * Params:
 *  dg        = delegate to execute in the created thread.
 *  stacksize = size of the stack of the created thread. The default of 0 will select the
 *              platform-specific default size.
 *  cbDllUnload = Windows only: if running in a dynamically loaded DLL, this delegate will be called
 *              if the DLL is supposed to be unloaded, but the thread is still running.
 *              The thread must be terminated via `joinLowLevelThread` by the callback.
 *
 * Returns: the platform specific thread ID of the new thread. If an error occurs, `ThreadID.init`
 *  is returned.
 */
ThreadID createLowLevelThread(void delegate() nothrow dg, uint stacksize = 0,
                              void delegate() nothrow cbDllUnload = null) nothrow @nogc
{
    void delegate() nothrow* context = cast(void delegate() nothrow*)malloc(dg.sizeof);
    *context = dg;

    ThreadID tid;
    version (Windows)
    {
        // the thread won't start until after the DLL is unloaded
        if (thread_DLLProcessDetaching)
            return ThreadID.init;

        static extern (Windows) uint thread_lowlevelEntry(void* ctx) nothrow
        {
            auto dg = *cast(void delegate() nothrow*)ctx;
            free(ctx);

            dg();
            ll_removeThread(GetCurrentThreadId());
            return 0;
        }

        // see Thread.start() for why thread is created in suspended state
        HANDLE hThread = cast(HANDLE) _beginthreadex(null, stacksize, &thread_lowlevelEntry,
                                                     context, CREATE_SUSPENDED, &tid);
        if (!hThread)
            return ThreadID.init;
    }

    lowlevelLock.lock_nothrow();
    scope(exit) lowlevelLock.unlock_nothrow();

    ll_nThreads++;
    ll_pThreads = cast(ll_ThreadData*)realloc(ll_pThreads, ll_ThreadData.sizeof * ll_nThreads);

    version (Windows)
    {
        ll_pThreads[ll_nThreads - 1].tid = tid;
        ll_pThreads[ll_nThreads - 1].cbDllUnload = cbDllUnload;
        if (ResumeThread(hThread) == -1)
            onThreadError("Error resuming thread");
        CloseHandle(hThread);

        if (cbDllUnload)
            ll_startDLLUnloadThread();
    }
    else version (Posix)
    {
        static extern (C) void* thread_lowlevelEntry(void* ctx) nothrow
        {
            auto dg = *cast(void delegate() nothrow*)ctx;
            free(ctx);

            dg();
            ll_removeThread(pthread_self());
            return null;
        }

        size_t stksz = adjustStackSize(stacksize);

        pthread_attr_t  attr;

        int rc;
        if ((rc = pthread_attr_init(&attr)) != 0)
            return ThreadID.init;
        if (stksz && (rc = pthread_attr_setstacksize(&attr, stksz)) != 0)
            return ThreadID.init;
        if ((rc = pthread_create(&tid, &attr, &thread_lowlevelEntry, context)) != 0)
            return ThreadID.init;
        if ((rc = pthread_attr_destroy(&attr)) != 0)
            return ThreadID.init;

        ll_pThreads[ll_nThreads - 1].tid = tid;
    }
    return tid;
}

/**
 * Wait for a thread created with `createLowLevelThread` to terminate.
 *
 * Note: In a Windows DLL, if this function is called via DllMain with
 *       argument DLL_PROCESS_DETACH, the thread is terminated forcefully
 *       without proper cleanup as a deadlock would happen otherwise.
 *
 * Params:
 *  tid = the thread ID returned by `createLowLevelThread`.
 */
void joinLowLevelThread(ThreadID tid) nothrow @nogc
{
    version (Windows)
    {
        HANDLE handle = OpenThreadHandle(tid);
        if (!handle)
            return;

        if (thread_DLLProcessDetaching)
        {
            // When being called from DllMain/DLL_DETACH_PROCESS, threads cannot stop
            //  due to the loader lock being held by the current thread.
            // On the other hand, the thread must not continue to run as it will crash
            //  if the DLL is unloaded. The best guess is to terminate it immediately.
            TerminateThread(handle, 1);
            WaitForSingleObject(handle, 10); // give it some time to terminate, but don't wait indefinitely
        }
        else
            WaitForSingleObject(handle, INFINITE);
        CloseHandle(handle);
    }
    else version (Posix)
    {
        if (pthread_join(tid, null) != 0)
            onThreadError("Unable to join thread");
    }
}

/**
 * Check whether a thread was created by `createLowLevelThread`.
 *
 * Params:
 *  tid = the platform specific thread ID.
 *
 * Returns: `true` if the thread was created by `createLowLevelThread` and is still running.
 */
bool findLowLevelThread(ThreadID tid) nothrow @nogc
{
    lowlevelLock.lock_nothrow();
    scope(exit) lowlevelLock.unlock_nothrow();

    foreach (i; 0 .. ll_nThreads)
        if (tid is ll_pThreads[i].tid)
            return true;
    return false;
}

nothrow @nogc unittest
{
    struct TaskWithContect
    {
        shared int n = 0;
        void run() nothrow
        {
            n.atomicOp!"+="(1);
        }
    }
    TaskWithContect task;

    ThreadID[8] tids;
    for (int i = 0; i < tids.length; i++)
        tids[i] = createLowLevelThread(&task.run);

    for (int i = 0; i < tids.length; i++)
        joinLowLevelThread(tids[i]);

    assert(task.n == tids.length);
}
