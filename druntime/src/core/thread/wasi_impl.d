/**
 * The wasi_impl module provides low-level WASI code
 * for thread creation and management.
 *
 * Copyright: Copyright ???
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   ???
 * Source:    $(DRUNTIMESRC core/thread/wasi_impl.d)
 */

module core.thread.wasi_impl;

import core.atomic;
import core.exception : onOutOfMemoryError;
import core.internal.traits : externDFunc;
import core.thread.osthread;
import core.thread.threadbase;
import core.time;

version (WASI):

// No real threading support
// Just manipulations of the main "thread"

version (WASIp1)
{
    import core.sys.wasi.p1 : ClockID, schedYield, Subscription, SubscriptionClock, pollOneOff, Event;
}
else version (WASIp2)
{
    import core.sys.wasi.p2.clocks.monotonic_clock.imports : subscribeDuration;
}

version (CoreDdoc) {} else
class Thread : ThreadBase
{
    package shared bool     m_isRunning;

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
    }

    static Thread getThis() @safe nothrow @nogc
    {
        return ThreadBase.getThis().toThread;
    }

    override final void[] savedRegisters() nothrow @nogc
    {
        return null;
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

        onThreadError("cannot start new threads on WASI");
    }

    override final Throwable join( bool rethrow = true )
    {
        throw new ThreadException( "Unable to join thread" );

        return super.join(rethrow);
    }

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

    final @property int priority()
    {
        return 0;
    }

    final @property void priority( int val )
    in
    {
        assert(val >= PRIORITY_MIN);
        assert(val <= PRIORITY_MAX);
    }
    do
    {
        // nothing
    }

    override final @property bool isRunning() nothrow @nogc
    {
        if (!super.isRunning())
            return false;

        // the "main thread" is the only that will pass super.isRunning(), and is always running
        return true;
    }

    static void sleep( Duration val ) @nogc nothrow @trusted
    in
    {
        assert( !val.isNegative );
    }
    do
    {
        version (WASIp1) {
            Subscription sub;
            sub.u.tag = Subscription.u.Tag.clock;
            sub.u.clock.id = ClockID.monotonic;
            sub.u.clock.timeout = val.total!"nsecs";

            size_t numEvents;
            Event event;
            auto err = pollOneOff((&sub)[0..1], (&event)[0..1], numEvents);
            if (err || event.error) assert(0, "Unable to sleep for the specified duration");

            return;
        }
        else version (WASIp2)
        {
            auto pollable = subscribeDuration(val.total!"nsecs");
            scope(exit) pollable.drop();

            pollable.block();
        }
    }

    static void yield() @nogc nothrow
    {
        version (WASIp1) schedYield();
        // else do nothing
    }
}
