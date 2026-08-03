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

import core.atomic;
import core.internal.traits : externDFunc;
import core.memory : GC;
import core.thread.context;
import core.thread.threadbase;
import core.thread.types;
import core.time;

///////////////////////////////////////////////////////////////////////////////
// Platform Detection and Memory Allocation
///////////////////////////////////////////////////////////////////////////////

version (Posix)
    public import core.thread.posix_impl;
else version (Windows)
    public import core.thread.windows_impl;
else
    static assert(false, "Unknown threading implementation.");

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

version (Windows)
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
else version (Posix)
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
        import core.sys.darwin.mach.port : mach_port_t;
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
else
    static assert(0, "unsupported operating system");

version (GNU)
{
    import gcc.builtins;
}

/**
 * Hook for whatever EH implementation is used to save/restore some data
 * per stack.
 *
 * Params:
 *     newContext = The return value of the prior call to this function
 *         where the stack was last swapped out, or null when a fiber stack
 *         is switched in for the first time.
 */
private extern(C) void* _d_eh_swapContext(void* newContext) nothrow @nogc;

version (DigitalMars)
{
    version (Windows)
    {
        extern(D) void* swapContext(void* newContext) nothrow @nogc
        {
            return _d_eh_swapContext(newContext);
        }
    }
    else
    {
        extern(C) void* _d_eh_swapContextDwarf(void* newContext) nothrow @nogc;

        extern(D) void* swapContext(void* newContext) nothrow @nogc
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
{
    extern(D) void* swapContext(void* newContext) nothrow @nogc
    {
        return _d_eh_swapContext(newContext);
    }
}

/**
 * This class encapsulates all threading functionality for the D
 * programming language.  As thread manipulation is a required facility
 * for garbage collection, all user threads should derive from this
 * class, and instances of this class should never be explicitly deleted.
 * A new thread may be created using either derivation or composition, as
 * in the following example.
 */
version (CoreDdoc)
class Thread : ThreadBase
{
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
    {
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
    {
    }

    package this( size_t sz = 0 ) @safe pure nothrow @nogc
    {
    }

    /**
     * Cleans up any remaining resources used by this object.
     */
    ~this() nothrow @nogc
    {
    }

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
        return null;
    }

    ///
    override final void[] savedRegisters() nothrow @nogc
    {
        return null;
    }

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
    {
        return null;
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
    override final Throwable join( bool rethrow = true )
    {
        return null;
    }

    /**
     * The minimum scheduling priority that may be set for a thread.  On
     * systems where multiple scheduling policies are defined, this value
     * represents the minimum valid priority for the scheduling policy of
     * the process.
     */
    @property static int PRIORITY_MIN() @nogc nothrow pure @trusted
    {
        return 0;
    }

    /**
     * The maximum scheduling priority that may be set for a thread.  On
     * systems where multiple scheduling policies are defined, this value
     * represents the maximum valid priority for the scheduling policy of
     * the process.
     */
    @property static const(int) PRIORITY_MAX() @nogc nothrow pure @trusted
    {
        return 0;
    }

    /**
     * The default scheduling priority that is set for a thread.  On
     * systems where multiple scheduling policies are defined, this value
     * represents the default priority for the scheduling policy of
     * the process.
     */
    @property static int PRIORITY_DEFAULT() @nogc nothrow pure @trusted
    {
        return 0;
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
        return 0;
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
    {
    }

    /**
     * Tests whether this thread is running.
     *
     * Returns:
     *  true if the thread is running, false if not.
     */
    override final @property bool isRunning() nothrow @nogc
    {
        return false;
    }

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
    static void sleep( Duration val ) @nogc nothrow @trusted
    {
    }

    /**
     * Forces a context switch to occur away from the calling thread.
     */
    static void yield() @nogc nothrow
    {
    }
}

package Thread toThread(return scope ThreadBase t) @trusted nothrow @nogc pure
{
    return cast(Thread) cast(void*) t;
}

private extern(D) static void thread_yield() @nogc nothrow
{
    Thread.yield();
}

///
static if (!isSingleThreaded)
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

static if (!isSingleThreaded)
unittest
{
    int x = 0;

    new Thread(
    {
        x++;
    }).start().join();
    assert( x == 1 );
}

static if (!isSingleThreaded)
unittest
{
    enum MSG = "Test message.";
    string caughtMsg;

    try
    {
        new Thread(
        function()
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

static if (!isSingleThreaded)
unittest
{
    // use >pageSize to avoid stack overflow (e.g. in an syscall)
    auto thr = new Thread(function{}, 4096 + 1).start();
    thr.join();
}

static if (!isSingleThreaded)
unittest
{
    import core.memory : GC;

    auto t1 = new Thread({
        foreach (_; 0 .. 20)
            ThreadBase.getAll;
    }).start;
    auto t2 = new Thread({
        foreach (_; 0 .. 20)
            GC.collect;
    }).start;
    t1.join();
    t2.join();
}

static if (!isSingleThreaded)
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

// https://issues.dlang.org/show_bug.cgi?id=22124
unittest
{
    Thread thread = new Thread({});
    auto fun(Thread t, int x)
    {
        t.__ctor({x = 3;});
        return t;
    }
    static assert(!__traits(compiles, () @nogc => fun(thread, 3) ));
}

@nogc @safe nothrow
unittest
{
    Thread.sleep(1.msecs);
}

unittest
{
    with(Thread)
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
}

static if (!isSingleThreaded)
unittest // Bugzilla 8960
{
    import core.sync.semaphore;

    with(Thread)
    {
        auto thr = new Thread({});
        thr.start();
        Thread.sleep(1.msecs);       // wait a little so the thread likely has finished
        thr.priority = PRIORITY_MAX; // setting priority doesn't cause error
        auto prio = thr.priority;    // getting priority doesn't cause error
        assert(prio >= PRIORITY_MIN && prio <= PRIORITY_MAX);
    }
}

///////////////////////////////////////////////////////////////////////////////
// GC Support Routines
///////////////////////////////////////////////////////////////////////////////

version (CoreDdoc)
{
    /**
     * Instruct the thread module, when initialized, to use a different set of
     * signals besides SIGRTMIN and SIGRTMIN + 1 for suspension and resumption of threads.
     * This function should be called at most once, prior to thread_init().
     * This function is Posix-only.
     */
    extern (C) void thread_setGCSignals(int suspendSignalNo, int resumeSignalNo) nothrow @nogc
    {
    }

    /**
     * Get the GC signals set by the thread module. This function should be called either
     * after thread_init() has finished, or after a call thread_setGCSignals().
     * This function is Posix-only.
     */
    extern (C) void thread_getGCSignals(out int suspendSignalNo, out int resumeSignalNo) nothrow @nogc
    {
    }
}

version (CoreDdoc) {} else
private extern (D) ThreadBase attachThread(ThreadBase _thisThread) @nogc nothrow
{
    Thread thisThread = _thisThread.toThread();

    StackContext* thisContext = &thisThread.m_main;
    assert( thisContext == thisThread.m_curr );

    thisThread.m_tdescr = Thread.getCurrentThreadDescr();
    thisContext.bstack = getStackBottom();
    thisContext.tstack = thisContext.bstack;

    version (Posix)
        atomicStore!(MemoryOrder.raw)(thisThread.toThread.m_isRunning, true);

    thisThread.m_isDaemon = true;
    thisThread.tlsRTdataInit();
    Thread.setThis( thisThread );

    Thread.add( thisThread, false );
    Thread.add( thisContext );
    if ( Thread.sm_main !is null )
        multiThreadedFlag = true;
    return thisThread;
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
 *
 * See_Also:
 *     $(REF thread_detachThis, core,thread,threadbase)
 */
extern(C) Thread thread_attachThis()
{
    return thread_attachThis_tpl!Thread();
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

        if (auto t = thread_findByAddr(addr).toThread)
            return t;

        Thread        thisThread  = new Thread();
        StackContext* thisContext = &thisThread.m_main;
        assert( thisContext == thisThread.m_curr );

        thisThread.m_tdescr.tid  = addr;
        thisContext.bstack = bstack;
        thisContext.tstack = thisContext.bstack;

        thisThread.m_isDaemon = true;

        if ( addr == GetCurrentThreadId() )
        {
            thisThread.m_tdescr.hndl = GetCurrentThreadHandle();
            thisThread.tlsRTdataInit();
            Thread.setThis( thisThread );
        }
        else
        {
            thisThread.m_tdescr.hndl = OpenThreadHandle( addr );
            impersonate_thread(addr,
            {
                thisThread.tlsRTdataInit();
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


// Calls the given delegate, passing the current thread's stack pointer to it.
package extern(D) void callWithStackShell(scope callWithStackShellDg fn) nothrow
in (fn)
{
    // The purpose of the 'shell' is to ensure all the registers get
    // put on the stack so they'll be scanned. We only need to push
    // the callee-save registers.
    void *sp = void;
    version (GNU)
    {
        // The generic solution below using a call to __builtin_unwind_init ()
        // followed by an assignment to sp has two issues:
        // 1) On some archs it stores a huge amount of FP and Vector state which
        //    is not the subject of the scan - and, indeed might produce false
        //    hits.
        // 2) Even on archs like X86, where there are no callee-saved FPRs/VRs there
        //    tend to be 'holes' in the frame allocations (to deal with alignment) which
        //    also will  contain random data which could produce false positives.
        // This solution stores only the integer callee-saved registers.
        version (X86)
        {
            void*[3] regs = void;
            asm pure nothrow @nogc
            {
                "movl   %%ebx, %0" : "=m" (regs[0]);
                "movl   %%esi, %0" : "=m" (regs[1]);
                "movl   %%edi, %0" : "=m" (regs[2]);
            }
            sp = cast(void*)&regs[0];
        }
        else version (X86_64)
        {
            void*[5] regs = void;
            asm pure nothrow @nogc
            {
                "movq   %%rbx, %0" : "=m" (regs[0]);
                "movq   %%r12, %0" : "=m" (regs[1]);
                "movq   %%r13, %0" : "=m" (regs[2]);
                "movq   %%r14, %0" : "=m" (regs[3]);
                "movq   %%r15, %0" : "=m" (regs[4]);
            }
            sp = cast(void*)&regs[0];
        }
        else version (PPC)
        {
            void*[19] regs = void;
            version (Darwin)
                enum regname = "r";
            else
                enum regname = "";
            static foreach (i; 0 .. regs.length)
            {{
                enum int j = 13 + i; // source register
                asm pure nothrow @nogc
                {
                    ("stw "~regname~j.stringof~", %0") : "=m" (regs[i]);
                }
            }}
            sp = cast(void*)&regs[0];
        }
        else version (PPC64)
        {
            void*[19] regs = void;
            version (Darwin)
                enum regname = "r";
            else
                enum regname = "";
            static foreach (i; 0 .. regs.length)
            {{
                enum int j = 13 + i; // source register
                asm pure nothrow @nogc
                {
                    ("std "~regname~j.stringof~", %0") : "=m" (regs[i]);
                }
            }}
            sp = cast(void*)&regs[0];
        }
        else version (AArch64)
        {
            // Callee-save registers, x19-x28 according to AAPCS64, section
            // 5.1.1.  Include x29 fp because it optionally can be a callee
            // saved reg
            size_t[11] regs = void;
            // store the registers in pairs
            asm pure nothrow @nogc
            {
                "stp x19, x20, %0" : "=m" (regs[ 0]), "=m" (regs[1]);
                "stp x21, x22, %0" : "=m" (regs[ 2]), "=m" (regs[3]);
                "stp x23, x24, %0" : "=m" (regs[ 4]), "=m" (regs[5]);
                "stp x25, x26, %0" : "=m" (regs[ 6]), "=m" (regs[7]);
                "stp x27, x28, %0" : "=m" (regs[ 8]), "=m" (regs[9]);
                "str x29, %0"      : "=m" (regs[10]);
                "mov %0, sp"       : "=r" (sp);
            }
        }
        else version (ARM)
        {
            // Callee-save registers, according to AAPCS, section 5.1.1.
            // arm and thumb2 instructions
            size_t[8] regs = void;
            asm pure nothrow @nogc
            {
                "stm %0, {r4-r11}" : : "r" (regs.ptr) : "memory";
                "mov %0, sp"       : "=r" (sp);
            }
        }
        else
        {
            __builtin_unwind_init();
            sp = &sp;
        }
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
    else version (AArch64)
    {
        // Callee-save registers, x19-x28 according to AAPCS64, section
        // 5.1.1.  Include x29 fp because it optionally can be a callee
        // saved reg
        size_t[11] regs = void;
        // store the registers in pairs
        asm pure nothrow @nogc
        {
        /*
            stp x19, x20, regs[0];
            stp x21, x22, regs[2];
            stp x23, x24, regs[4];
            stp x25, x26, regs[6];
            stp x27, x28, regs[8];
            str x29, regs[10];
            mov [sp], sp;
         */
        }
        assert(0, "implement AArch64 inline assembler for callWithStackShell()"); // TODO AArch64
    }
    else
    {
        static assert(false, "Architecture not supported.");
    }

    fn(sp);
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
version (CoreDdoc)
{
    size_t getpid() nothrow @nogc { return 0; }
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
    version (OpenBSD) int pthread_stackseg_np(pthread_t thread, stack_t* sinfo);
}


private extern(D) void* getStackTop() nothrow @nogc
{
    version (D_InlineAsm_X86)
        asm pure nothrow @nogc { naked; mov EAX, ESP; ret; }
    else version (D_InlineAsm_X86_64)
        asm pure nothrow @nogc { naked; mov RAX, RSP; ret; }
    else version (AArch64)
        //asm pure nothrow @nogc { naked; mov x0, SP; ret; }    // TODO AArch64
    {
        return null;
    }
    else version (GNU)
        return __builtin_frame_address(0);
    else
        static assert(false, "Architecture not supported.");
}


private extern(D) void* getStackBottom() nothrow @nogc
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
        else version (GNU_InlineAsm)
        {
            void *bottom;

            version (X86)
                asm pure nothrow @nogc { "movl %%fs:4, %0;" : "=r" (bottom); }
            else version (X86_64)
                asm pure nothrow @nogc { "movq %%gs:8, %0;" : "=r" (bottom); }
            else
                static assert(false, "Architecture not supported.");

            return bottom;
        }
        else
            static assert(false, "Architecture not supported.");
    }
    else version (Darwin)
    {
        import core.sys.darwin.pthread : pthread_get_stackaddr_np;
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
        static if (isStackGrowingDown)
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
        static if (isStackGrowingDown)
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
private extern (D) bool suspend( Thread t ) nothrow @nogc
{
    if (!t.isRunning)
    {
        Thread.remove(t);
        return false;
    }

    const sameThread = t.m_tdescr.tid == gettid();

    if (!sameThread)
    {
        if (!suspendThreadImpl(t))
        {
            if (t.isRunning)
                onThreadError( "Unable to suspend thread" );
            else
            {
                Thread.remove( t );
                return false;
            }
        }
    }

    loadStackAndRegInfo(t, sameThread);

    return true;
}

/**
 * Runs the necessary operations required before stopping the world.
 */
extern (C) void thread_preStopTheWorld() nothrow {
    Thread.slock.lock_nothrow();
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

    thread_preStopTheWorld();
    {
        if ( ++suspendDepth > 1 )
            return;

        size_t cnt;
        bool suspendedSelf;
        Thread t = ThreadBase.sm_tbeg.toThread;
        while (t)
        {
            auto tn = t.next.toThread;
            if (suspend(t))
            {
                if (t is ThreadBase.getThis())
                    suspendedSelf = true;
                ++cnt;
            }
            t = tn;
        }

        version (Darwin)
        {}
        else version (Solaris)
        {}
        else version (WASI)
        {}
        else version (Posix)
        {
            // Subtract own thread if we called suspend() on ourselves.
            // For example, suspendedSelf would be false if the current
            // thread ran thread_detachThis().
            assert(cnt >= 1);
            if (suspendedSelf)
                --cnt;
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
        }
        else version (Windows)
        {
        }
        else
            static assert(0, "unsupported os");
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
private extern (D) void resume(ThreadBase _t) nothrow @nogc
{
    Thread t = _t.toThread;
    const sameThread = t.m_tdescr.tid == gettid();

    if (!sameThread)
    {
        if (!resumeThreadImpl(t))
        {
            if (t.isRunning)
                onThreadError( "Unable to resume thread" );
            else
            {
                Thread.remove( t );
                return;
            }
        }
    }

    purgeStackAndRegInfo(t, sameThread);
}

private void purgeStackAndRegInfo(Thread t, const bool sameThread) nothrow @nogc
{
    version (Windows)
    {
        t.unloadStackInfo();
        t.m_reg[0 .. $] = 0;
    }
    else version (Darwin)
    {
        t.unloadStackInfo();
        t.m_reg[0 .. $] = 0;
    }
    else version (Solaris)
    {
        t.unloadStackInfo();
        t.m_reg[0 .. $] = 0;
    }
    else version (Posix)
    {
        if (sameThread)
            t.unloadStackInfo();
    }
    else
        static assert(false, "Platform not supported.");
}


/**
 * Initializes the thread module.  This function must be called by the
 * garbage collector on startup and before any other thread routines
 * are called.
 */
version (CoreDdoc)
    extern (C) void thread_init() @nogc nothrow {}
else
extern (C) void thread_init() @nogc nothrow
{
    // NOTE: If thread_init itself performs any allocations then the thread
    //       routines reserved for garbage collector use may be called while
    //       thread_init is being processed.  However, since no memory should
    //       exist to be scanned at this point, it is sufficient for these
    //       functions to detect the condition and return immediately.

    initLowlevelThreads();
    Thread.initLocks();
    Thread.afterDeploy();

    version (Windows)
    {
    }
    else version (Darwin)
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
    else version (WASI)
    {
    }
    else version (Posix)
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
    else
        static assert(0, "unsupported os");
    _mainThreadStore[] = cast(void[]) __traits(initSymbol, Thread)[];
    Thread.sm_main = attachThread((cast(Thread)_mainThreadStore.ptr).__ctor());
}

private alias MainThreadStore = void[__traits(classInstanceSize, Thread)];
package __gshared align(__traits(classInstanceAlignment, Thread)) MainThreadStore _mainThreadStore;

/**
 * Terminates the thread module. No other thread routine may be called
 * afterwards.
 */
extern (C) void thread_term() @nogc nothrow
{
    thread_term_tpl!(Thread)(_mainThreadStore);
}


///////////////////////////////////////////////////////////////////////////////
// Thread Entry Point and Signal Handlers
///////////////////////////////////////////////////////////////////////////////


version (Windows)
{
    package
    {
        //
        // Entry point for Windows threads
        //
        extern (Windows) uint thread_entryPoint( void* arg ) nothrow
        {
            Thread  obj = cast(Thread) arg;
            assert( obj );

            obj.initDataStorage();

            Thread.registerThis(obj);

            scope (exit)
            {
                // allow the GC to clean up any resources it allocated for this thread.
                import core.internal.gc.proxy : gc_getProxy;
                gc_getProxy().cleanupThread(obj);

                Thread.remove(obj);
                obj.destroyDataStorage();
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
                obj.filterCaughtThrowable(t);
                if (t !is null)
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
                    obj.runFromEntryPoint();
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
    // NOTE: A thread's cancelability state, determined by pthread_setcancelstate,
    //       can be enabled (the default for new threads) or disabled.
    //       If a thread has disabled cancelation, then a cancelation request remains
    //       queued until the thread enables cancelation.  If a thread has enabled
    //       cancelation, then its cancelability type determines when cancelation occurs.
    //
    // Call these routines when entering/leaving critical sections of the code that
    // are not cancellation points.

    extern (C) int thread_cancelDisable() nothrow
    {
        static if (__traits(compiles, core.sys.posix.pthread.PTHREAD_CANCEL_DISABLE))
        {
            import core.sys.posix.pthread : pthread_setcancelstate, PTHREAD_CANCEL_DISABLE;
            int oldstate;
            pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &oldstate);
            return oldstate;
        }
        else
        {
            return 0;   // No thread cancellation on platform
        }
    }

    extern (C) void thread_cancelRestore(int oldstate) nothrow
    {
        static if (__traits(compiles, core.sys.posix.pthread.PTHREAD_CANCEL_DISABLE))
        {
            import core.sys.posix.pthread : pthread_setcancelstate;
            pthread_setcancelstate(oldstate, null);
        }
    }

    package
    {
        //
        // Entry point for POSIX threads
        //
        version (CoreDdoc) {} else
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

            obj.initDataStorage();

            atomicStore!(MemoryOrder.raw)(obj.m_isRunning, true);

            Thread.registerThis(obj); // can only receive signals from here on

            scope (exit)
            {
                // allow the GC to clean up any resources it allocated for this thread.
                import core.internal.gc.proxy : gc_getProxy;
                gc_getProxy().cleanupThread(obj);

                Thread.remove(obj);
                atomicStore!(MemoryOrder.raw)(obj.m_isRunning, false);
                obj.destroyDataStorage();
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
            static if (__traits(compiles, core.sys.posix.pthread.pthread_cleanup))
            {
                import core.sys.posix.pthread : pthread_cleanup;

                pthread_cleanup cleanup = void;
                cleanup.push( &thread_cleanupHandler, cast(void*) obj );
            }
            else static if (__traits(compiles, core.sys.posix.pthread.pthread_cleanup_push))
            {
                import core.sys.posix.pthread : pthread_cleanup_push;

                pthread_cleanup_push(&thread_cleanupHandler, cast(void*) obj);
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
                obj.filterCaughtThrowable(t);
                if (t !is null)
                    obj.m_unhandled = Throwable.chainTogether(obj.m_unhandled, t);
            }
            try
            {
                rt_moduleTlsCtor();
                try
                {
                    obj.runFromEntryPoint();
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

            static if (__traits(compiles, core.sys.posix.pthread.pthread_cleanup))
            {
                cleanup.pop( 0 );
            }
            else static if (__traits(compiles, core.sys.posix.pthread.pthread_cleanup_push))
            {
                import core.sys.posix.pthread : pthread_cleanup_pop;

                pthread_cleanup_pop( 0 );
            }

            return null;
        }


        version (WASI) {}
        else
        {
            //
            // Used to track the number of suspended threads
            //
            __gshared sem_t suspendCount;


            extern (C) bool thread_preSuspend( void* sp ) nothrow {
                // NOTE: Since registers are being pushed and popped from the
                //       stack, any other stack data used by this function should
                //       be gone before the stack cleanup code is called below.
                Thread obj = Thread.getThis();
                if (obj is null)
                {
                    return false;
                }

                if ( !obj.m_lock )
                {
                    obj.m_curr.tstack = sp;
                }

                return true;
            }

            extern (C) bool thread_postSuspend() nothrow {
                Thread obj = Thread.getThis();
                if (obj is null)
                {
                    return false;
                }

                if ( !obj.m_lock )
                {
                    obj.m_curr.tstack = obj.m_curr.bstack;
                }

                return true;
            }

            extern (C) void thread_suspendHandler( int sig ) nothrow
            in
            {
                assert( sig == suspendSignalNumber );
            }
            do
            {
                void op(void* sp) nothrow
                {
                    int cancel_state = thread_cancelDisable();
                    scope(exit) thread_cancelRestore(cancel_state);

                    bool supported = thread_preSuspend(getStackTop());
                    assert(supported, "Tried to suspend a detached thread!");

                    scope(exit)
                    {
                        supported = thread_postSuspend();
                        assert(supported, "Tried to suspend a detached thread!");
                    }

                    sigset_t    sigres = void;
                    int         status;

                    status = sigfillset( &sigres );
                    assert( status == 0 );

                    status = sigdelset( &sigres, resumeSignalNumber );
                    assert( status == 0 );

                    status = sem_post( &suspendCount );
                    assert( status == 0 );

                    sigsuspend( &sigres );
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

//
// exposed by compiler runtime
//
extern (C) void  rt_moduleTlsCtor();
extern (C) void  rt_moduleTlsDtor();


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


///////////////////////////////////////////////////////////////////////////////
// lowlovel threading support
///////////////////////////////////////////////////////////////////////////////

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
    auto tprop = cast(LLThreadProperties*) malloc(LLThreadProperties.sizeof);
    scope(exit) free(tprop);

    auto context = LLThreadContext(stacksize, cbDllUnload);

    if(tprop.initialize(dg, context) == false)
        return ThreadID.init;

    lowlevelLock.lock_nothrow();
    scope(exit) lowlevelLock.unlock_nothrow();

    const next_idx = ll_nThreads;
    ll_nThreads++;
    ll_pThreads = cast(ll_ThreadData*)realloc(ll_pThreads, ll_ThreadData.sizeof * ll_nThreads);
    ref ll_next = ll_pThreads[next_idx];
    ll_next = ll_ThreadData.init;

    if(launchLLThread(tprop, context, ll_next) == false)
        return ThreadID.init;

    tprop = null; // free'd in thread
    return context.tid;
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
version (CoreDdoc)
void joinLowLevelThread(ThreadID tid) nothrow @nogc {}

static if (!isSingleThreaded)
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
    {
        tids[i] = createLowLevelThread(&task.run);
        assert(tids[i] != ThreadID.init);
    }

    for (int i = 0; i < tids.length; i++)
        joinLowLevelThread(tids[i]);

    assert(atomicLoad(task.n) == tids.length);
}
