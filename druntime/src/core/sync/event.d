/**
 * The event module provides a primitive for lightweight signaling of other threads
 * (emulating Windows events on Posix)
 *
 * Copyright: Copyright (c) 2019 D Language Foundation
 * License: Distributed under the
 *    $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors: Rainer Schuetze
 * Source:    $(DRUNTIMESRC core/sync/event.d)
 */
module core.sync.event;

import core.time;
import core.sync.event_impl;

/**
 * represents an event. Clients of an event are suspended while waiting
 * for the event to be "signaled".
 *
 * Implemented using `pthread_mutex` and `pthread_condition` on Posix and
 * `CreateEvent` and `SetEvent` on Windows.
---
import core.sync.event, core.thread, std.file;

struct ProcessFile
{
    ThreadGroup group;
    Event event;
    void[] buffer;

    void doProcess()
    {
        event.wait();
        // process buffer
    }

    void process(string filename)
    {
        event.initialize(true, false);
        group = new ThreadGroup;
        for (int i = 0; i < 10; ++i)
            group.create(&doProcess);

        buffer = std.file.read(filename);
        event.setIfInitialized();
        group.joinAll();
        event.terminate();
    }
}
---
 */
struct Event
{
nothrow @nogc:

    private core.sync.event_impl.EventHandler hdl;

    /**
     * Creates an event object.
     *
     * Params:
     *  manualReset  = the state of the event is not reset automatically after resuming waiting clients
     *  initialState = initial state of the signal
     */
    this(bool manualReset, bool initialState)
    {
        initialize(manualReset, initialState);
    }

    /**
     * Initializes an event object. Does nothing if the event is already initialized.
     *
     * Params:
     *  manualReset  = the state of the event is not reset automatically after resuming waiting clients
     *  initialState = initial state of the signal
     */
    void initialize(bool manualReset, bool initialState)
    {
        if(hdl.initalized)
            return;

        hdl = core.sync.event_impl.create(manualReset, initialState);
    }

    // copying not allowed, can produce resource leaks
    @disable this(this);
    @disable void opAssign(Event);

    ~this()
    {
        terminate();
    }

    /**
     * deinitialize event. Does nothing if the event is not initialized. There must not be
     * threads currently waiting for the event to be signaled.
    */
    void terminate()
    {
        if (hdl.initalized)
            core.sync.event_impl.destroy(hdl);
    }

    deprecated ("Use setIfInitialized() instead") void set()
    {
        setIfInitialized();
    }

    /// Set the event to "signaled", so that waiting clients are resumed
    void setIfInitialized()
    {
        if (hdl.initalized)
            core.sync.event_impl.set(hdl);
    }

    /// Reset the event manually
    void reset()
    {
        if (hdl.initalized)
            core.sync.event_impl.reset(hdl);
    }

    /**
     * Wait for the event to be signaled without timeout.
     *
     * Returns:
     *  `true` if the event is in signaled state, `false` if the event is uninitialized or another error occured
     */
    bool wait()
    {
        return core.sync.event_impl.wait(hdl);
    }

    /**
     * Wait for the event to be signaled with timeout.
     *
     * Params:
     *  tmout = the maximum time to wait
     * Returns:
     *  `true` if the event is in signaled state, `false` if the event was nonsignaled for the given time or
     *  the event is uninitialized or another error occured
     */
    bool wait(Duration tmout)
    {
        if (!hdl.initalized)
            return false;

        return core.sync.event_impl.wait(hdl, tmout);
    }
}

// Test single-thread (non-shared) use.
@nogc nothrow unittest
{
    // auto-reset, initial state false
    Event ev1 = Event(false, false);
    assert(!ev1.wait(1.dur!"msecs"));
    ev1.setIfInitialized();
    assert(ev1.wait());
    assert(!ev1.wait(1.dur!"msecs"));

    // manual-reset, initial state true
    Event ev2 = Event(true, true);
    assert(ev2.wait());
    assert(ev2.wait());
    ev2.reset();
    assert(!ev2.wait(1.dur!"msecs"));
}

unittest
{
    import core.thread, core.atomic;

    scope event      = new Event(true, false);
    int  numThreads = 10;
    shared int numRunning = 0;

    void testFn()
    {
        event.wait(8.dur!"seconds"); // timeout below limit for druntime test_runner
        numRunning.atomicOp!"+="(1);
    }

    auto group = new ThreadGroup;

    for (int i = 0; i < numThreads; ++i)
        group.create(&testFn);

    auto start = MonoTime.currTime;
    assert(numRunning == 0);

    event.setIfInitialized();
    group.joinAll();

    assert(numRunning == numThreads);

    assert(MonoTime.currTime - start < 5.dur!"seconds");
}
