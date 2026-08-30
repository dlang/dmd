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
import core.memory : GC;
import core.thread.context : StackContext;
import core.thread.osthread;
import core.thread.threadbase;
import core.thread.types : ThreadID, ThreadDescr, ll_ThreadData;
import core.time;

version (Windows):

version (all)
{
    import core.stdc.stdint : uintptr_t; // for _beginthreadex decl below
    import core.stdc.stdlib : free, malloc, realloc;
    import core.sys.windows.basetsd /+: HANDLE+/;
    import core.sys.windows.threadaux : getThreadStackBottom, impersonate_thread, OpenThreadHandle;
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

package void* swapContextImpl()(void* newContext) nothrow @nogc
{
    return _d_eh_swapContext(newContext);
}

package enum isSingleThreaded = false;

version (CoreDdoc) {} else
class Thread : ThreadBase
{
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

        m_tdescr.tid = m_tdescr.tid.init;
        CloseHandle( m_tdescr.hndl );
        m_tdescr.hndl = m_tdescr.hndl.init;
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
            m_tdescr.hndl = cast(HANDLE) _beginthreadex( null, cast(uint) m_sz, &thread_entryPoint, cast(void*) this, CREATE_SUSPENDED, &m_tdescr.tid );
            if ( cast(size_t) m_tdescr.hndl == 0 )
                onThreadError( "Error creating thread" );
        }

        slock.lock_nothrow();
        scope(exit) slock.unlock_nothrow();
        {
            incrementAboutToStart(this);
            scope(failure) decrementAboutToStart(this);

            if ( ResumeThread( m_tdescr.hndl ) == -1 )
                onThreadError( "Error resuming thread" );

            return this;
        }
    }

    override final Throwable join( bool rethrow = true )
    {
        if ( m_tdescr.tid != m_tdescr.tid.init && WaitForSingleObject( m_tdescr.hndl, INFINITE ) != WAIT_OBJECT_0 )
            throw new ThreadException( "Unable to join thread" );
        // NOTE: tid must be cleared before hndl is closed to avoid
        //       a race condition with isRunning. The operation is done
        //       with atomicStore to prevent compiler reordering.
        atomicStore!(MemoryOrder.raw)(*cast(shared)&m_tdescr.tid, m_tdescr.tid.init);
        CloseHandle( m_tdescr.hndl );
        m_tdescr.hndl = m_tdescr.hndl.init;

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
        return GetThreadPriority( m_tdescr.hndl );
    }

    final @property void priority( int val )
    in
    {
        assert(val >= PRIORITY_MIN);
        assert(val <= PRIORITY_MAX);
    }
    do
    {
        if ( !SetThreadPriority( m_tdescr.hndl, val ) )
            throw new ThreadException( "Unable to set thread priority" );
    }

    override final @property bool isRunning() nothrow @nogc
    {
        if (!super.isRunning())
            return false;

        uint ecode = 0;
        GetExitCodeThread( m_tdescr.hndl, &ecode );
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

    package static ThreadDescr getCurrentThreadDescr() nothrow @nogc
    {
        return ThreadDescr(
            tid: gettid,
            hndl: GetCurrentThreadHandle()
        );
    }

    package static void afterDeploy() nothrow @nogc { /* do nothing */ }
}

private
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
    package(core) extern (C) Thread thread_attachByAddr( ThreadID addr )
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

private
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

version (CoreDdoc) {} else
public  alias getpid = imported!"core.sys.windows.winbase".GetCurrentProcessId;

package alias gettid = imported!"core.sys.windows.winbase".GetCurrentThreadId;

package void* getStackBottomImpl() nothrow @nogc
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

// Returns true on success
package bool suspendThreadImpl(Thread t) @nogc nothrow
{
    return SuspendThread(t.m_tdescr.hndl) != 0xFFFFFFFF;
}

// Returns true on success
package bool resumeThreadImpl(Thread t) @nogc nothrow
{
    return ResumeThread(t.m_tdescr.hndl) != 0xFFFFFFFF;
}

package void afterStopTheWorld(bool suspendedSelf, size_t cnt) @nogc nothrow { /* do nothing */ }

package void loadStackAndRegInfo(Thread t, const bool sameThread) nothrow @nogc
{
    CONTEXT context = void;
    context.ContextFlags = CONTEXT_INTEGER | CONTEXT_CONTROL;

    if ( !GetThreadContext( t.m_tdescr.hndl, &context ) )
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
    // a thread might change the stack, e.g. using non-D fibers, so we must not
    // rely on the stack bottom saved when attaching/starting. Multiple fiber stacks cannot be
    // captured, but make sure scanning does not crash accessing invalid memory ranges
    // between stacks
    if ( !t.m_lock )
        t.m_curr.bstack = getThreadStackBottom( t.m_tdescr.hndl );
}

package void purgeStackAndRegInfo(Thread t, const bool sameThread) nothrow @nogc
{
    t.unloadStackInfo();
    t.m_reg[0 .. $] = 0;
}

private
{
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

    import core.sys.windows.dll : dll_getRefCount;
    import core.sys.windows.winbase : FreeLibraryAndExitThread, GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS, GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, GetModuleHandleExW;
    import core.sys.windows.windef : HMODULE;

    version (CRuntime_Microsoft)
        extern(C) extern __gshared ubyte msvcUsesUCRT; // from rt/msvc.d
    extern(C) extern __gshared void* __ImageBase; // symbol at the beginning of module, added by linker
    enum HMODULE runtimeModule = &__ImageBase;

    /// set during termination of a DLL on Windows, i.e. while executing DllMain(DLL_PROCESS_DETACH)
    public __gshared bool thread_DLLProcessDetaching;

    __gshared ThreadID ll_dllMonitorThread;

    int ll_countLowLevelThreadsWithDLLUnloadCallback(HMODULE hMod) nothrow
    {
        lowlevelLock.lock_nothrow();
        scope(exit) lowlevelLock.unlock_nothrow();

        int cnt = 0;
        foreach (i; 0 .. ll_nThreads)
            if (ll_pThreads[i].cbDllUnload && ll_pThreads[i].hMod == hMod)
                cnt++;
        return cnt;
    }

    bool ll_dllHasExternalReferences(HMODULE hMod) nothrow
    {
        int unloadCallbacks = ll_countLowLevelThreadsWithDLLUnloadCallback(hMod);
        int internalReferences = hMod != runtimeModule ? unloadCallbacks
            : (ll_dllMonitorThread ? 1 : 0) + (msvcUsesUCRT ? unloadCallbacks : 0);
        int refcnt = dll_getRefCount(hMod);
        return refcnt > internalReferences;
    }

    void notifyUnloadLowLevelThreads(HMODULE hMod) nothrow
    {
        HMODULE toFree;
        for (;;)
        {
            ThreadID tid;
            void delegate() nothrow cbDllUnload;
            {
                lowlevelLock.lock_nothrow();
                scope(exit) lowlevelLock.unlock_nothrow();

                foreach (i; 0 .. ll_nThreads)
                    if (ll_pThreads[i].cbDllUnload && ll_pThreads[i].hMod == hMod)
                    {
                        if (!toFree)
                            toFree = ll_getModuleHandle(hMod, true); // keep the module alive until the callback returns
                        cbDllUnload = ll_pThreads[i].cbDllUnload;
                        tid = ll_pThreads[i].tid;
                        break;
                    }
            }
            if (!cbDllUnload)
                break;
            cbDllUnload(); // must wait for thread termination
            assert(!findLowLevelThread(tid));
        }
        if (toFree)
            FreeLibrary(toFree);
    }

    private void monitorDLLRefCnt() nothrow
    {
        // this thread keeps the DLL alive until all external references are gone
        // (including those from DLLs using druntime in a shared DLL)
        while (ll_dllHasExternalReferences(runtimeModule))
        {
            // find and unload module that only has internal references left
            HMODULE hMod;
            {
                lowlevelLock.lock_nothrow();
                scope(exit) lowlevelLock.unlock_nothrow();

                foreach (i; 0 .. ll_nThreads)
                    if (ll_pThreads[i].cbDllUnload && ll_pThreads[i].hMod != runtimeModule)
                        if (!ll_dllHasExternalReferences(ll_pThreads[i].hMod))
                        {
                            hMod = ll_pThreads[i].hMod;
                            break;
                        }
            }
            if (hMod)
                notifyUnloadLowLevelThreads(hMod);
            else
                Thread.sleep(100.msecs);
        }

        notifyUnloadLowLevelThreads(runtimeModule);

        // the current thread will be terminated without cleanup within the thread
        ll_removeThread(GetCurrentThreadId());

        FreeLibraryAndExitThread(runtimeModule, 0);
    }

    HMODULE ll_getModuleHandle(void* funcptr, bool addref = false) nothrow @nogc
    {
        HMODULE hmod;
        DWORD refflag = addref ? 0 : GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT;
        if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | refflag,
                                cast(const(wchar)*) funcptr, &hmod))
            return null;
        return hmod;
    }

    bool ll_startDLLUnloadThread() nothrow @nogc
    {
        if (ll_dllMonitorThread !is ThreadID.init)
            return true;

        // if a thread is created from a DLL, the MS runtime (starting with VC2015) increments the DLL reference count
        // to avoid the DLL being unloaded while the thread is still running. Mimick this behavior here for all
        // runtimes not doing this
        bool needRef = !msvcUsesUCRT;
        if (needRef)
            ll_getModuleHandle(runtimeModule, true);

        // the monitor thread must be a low-level thread so the runtime does not attach to it
        ll_dllMonitorThread = createLowLevelThread(() { monitorDLLRefCnt(); });
        return ll_dllMonitorThread != ThreadID.init;
    }
}

package struct LLThreadProperties
{
    void delegate() nothrow dg;
    HMODULE cbMod;

    bool initialize(void delegate() nothrow _dg, ref LLThreadContext context) nothrow @nogc
    {
        dg = _dg;

        // the thread won't start until after the DLL is unloaded
        if (thread_DLLProcessDetaching)
            return false;

        cbMod = context.cbDllUnload ? ll_getModuleHandle(context.cbDllUnload.funcptr) : null;
        if (cbMod)
        {
            int refcnt = dll_getRefCount(cbMod);
            if (refcnt < 0)
            {
                // not a dynamically loaded DLL, so never unloaded
                context.cbDllUnload = null;
                cbMod = null;
            }
            if (refcnt == 0)
                return false; // createLowLevelThread called while DLL is unloading
        }

        static extern (Windows) uint thread_lowlevelEntry(void* ctx) nothrow
        {
            auto tprop = *cast(LLThreadProperties*)ctx;
            free(ctx);

            tprop.dg();

            ll_removeThread(GetCurrentThreadId());
            if (tprop.cbMod && tprop.cbMod != runtimeModule)
                FreeLibrary(tprop.cbMod);
            return 0;
        }

        // see Thread.start() for why thread is created in suspended state
        context.hThread = cast(HANDLE) _beginthreadex(null, context.stacksize, &thread_lowlevelEntry,
                                                     &this, CREATE_SUSPENDED, &context.tid);
        if (!context.hThread)
            return false;

        return true;
    }
}

package struct LLThreadContext
{
    ThreadID tid;
    uint stacksize;
    void delegate() nothrow cbDllUnload;
    HANDLE hThread;

    this(uint stacksize, void delegate() nothrow cbDllUnload) nothrow @nogc
    {
        this.stacksize = stacksize;
        this.cbDllUnload = cbDllUnload;
    }
}

// Returns: false if error occurred
package bool launchLLThread(LLThreadProperties* tprop, ref LLThreadContext context, ref ll_ThreadData curr_llt) nothrow @nogc
{
    curr_llt.tid = context.tid;
    // ignore callback if not a dynamically loaded DLL
    if (context.cbDllUnload)
    {
        curr_llt.cbDllUnload = context.cbDllUnload;
        curr_llt.hMod = tprop.cbMod;
        if (tprop.cbMod != runtimeModule)
            ll_getModuleHandle(tprop.cbMod, true); // increment ref count
    }

    if (ResumeThread(context.hThread) == -1)
        onThreadError("Error resuming thread");
    CloseHandle(context.hThread);

    if (context.cbDllUnload)
        ll_startDLLUnloadThread();

    return true;
}

version (CoreDdoc) {} else
void joinLowLevelThread(ThreadID tid) nothrow @nogc
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
