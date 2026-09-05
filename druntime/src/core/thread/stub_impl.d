/// Single-threaded Thread stub
module core.thread.stub_impl;

import core.thread.osthread: toThread;
import core.thread.threadbase;
import core.time: Duration;
import core.thread.types: ll_ThreadData, ThreadDescr;

package(core) enum isSingleThreaded = true;

private alias ThreadID = size_t;
private immutable assertMsg = "threading not implemented";

version (CoreDdoc)
    import core.thread.osthread: Thread;
else
class Thread : ThreadBase
{
    private bool started;
    private void function() fn;
    private void delegate() dg;

    this(void function() fn, size_t sz = 0) @safe pure nothrow @nogc
    {
        this.fn = fn;
    }

    this(void delegate() dg, size_t sz = 0) @safe pure nothrow @nogc
    {
        this.dg = dg;
    }

    package this( size_t sz = 0 ) @safe pure nothrow @nogc {}

    ~this() nothrow @nogc {}

    static Thread getThis() @safe nothrow @nogc
    {
        return ThreadBase.getThis().toThread!Thread;
    }

    override final void[] savedRegisters() nothrow @nogc
    {
        return null;
    }

    final Thread start()
    {
        started = true;

        return this;
    }

    override final Throwable join( bool rethrow = true )
    {
        if(!started)
            return null;

        if(rethrow)
            run();
        else
        {
            try
                run();
            catch(Exception e)
                return e;
        }

        return null;
    }

    private void run()
    {
        if(dg !is null)
        {
            dg();
            dg = null;
        }
        else if(fn !is null)
        {
            fn();
            fn = null;
        }
    }

    @property static int PRIORITY_MIN() @nogc nothrow pure @trusted
    {
        assert(false, assertMsg);
    }

    @property static const(int) PRIORITY_MAX() @nogc nothrow pure @trusted
    {
        assert(false, assertMsg);
    }

    @property static int PRIORITY_DEFAULT() @nogc nothrow pure @trusted
    {
        assert(false, assertMsg);
    }

    final @property int priority()
    {
        assert(false, assertMsg);
    }

    final @property void priority( int val )
    {
        assert(false, assertMsg);
    }

    override final @property bool isRunning() nothrow @nogc => true;

    static void sleep( Duration val ) @nogc nothrow @trusted
    {}

    static void yield() @nogc nothrow
    {
        assert(false, assertMsg);
    }

    package static ThreadDescr getCurrentThreadDescr() nothrow @nogc
    {
        return ThreadDescr.init;
    }

    package static void afterDeploy() nothrow @nogc {}
}

// Returns true on success
package bool suspendThreadImpl(Thread t) @nogc nothrow
{
    assert(false, assertMsg);
}

// Returns true on success
package bool resumeThreadImpl(Thread t) @nogc nothrow
{
    assert(false, assertMsg);
}

package void afterStopTheWorld(bool suspendedSelf, size_t cnt) @nogc nothrow
{
    assert(false, assertMsg);
}

package void loadStackAndRegInfo(Thread t, const bool sameThread) nothrow @nogc
{}

package void purgeStackAndRegInfo(Thread t, const bool sameThread) nothrow @nogc
{}

package auto gettid() => ThreadID.init;

version (Posix)
    import thirdParty = core.thread.posix_impl;
else version (Windows)
    import thirdParty = core.thread.windows_impl;
else
    static assert(false, "Platform not supported.");

alias getStackBottomImpl = thirdParty.getStackBottomImpl;
alias swapContextImpl = thirdParty.swapContextImpl;

version (CoreDdoc) {}
else
    alias getpid = thirdParty.getpid;

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
    }
}

// Returns: false if error occurred
package bool launchLLThread(LLThreadProperties* tprop, ref LLThreadContext context, ref ll_ThreadData curr_llt) nothrow @nogc
{
    assert(false, assertMsg);
}

version (CoreDdoc) {} else
void joinLowLevelThread(ThreadID tid) nothrow @nogc
{
    assert(false, assertMsg);
}
