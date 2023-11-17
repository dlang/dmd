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

import core.sys.windows.basetsd /+: HANDLE +/;
import core.sys.windows.winerror /+: WAIT_TIMEOUT +/;
import core.sys.windows.winbase /+: CreateEvent, CloseHandle, SetEvent, ResetEvent,
    WaitForSingleObject, INFINITE, WAIT_OBJECT_0+/;

import core.time;
import core.internal.abort : abort;

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
            if (m_event)
                return;
            m_event = CreateEvent(null, manualReset, initialState, null);
            m_event || abort("Error: CreateEvent failed.");
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
            if (m_event)
                CloseHandle(m_event);
            m_event = null;
    }

    deprecated ("Use setIfInitialized() instead") void set()
    {
        setIfInitialized();
    }

    /// Set the event to "signaled", so that waiting clients are resumed
    void setIfInitialized()
    {
            if (m_event)
                SetEvent(m_event);
    }

    /// Reset the event manually
    void reset()
    {
            if (m_event)
                ResetEvent(m_event);
    }

    /**
     * Wait for the event to be signaled without timeout.
     *
     * Returns:
     *  `true` if the event is in signaled state, `false` if the event is uninitialized or another error occured
     */
    bool wait()
    {
            return m_event && WaitForSingleObject(m_event, INFINITE) == WAIT_OBJECT_0;
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
            if (!m_event)
                return false;

            auto maxWaitMillis = dur!("msecs")(uint.max - 1);

            while (tmout > maxWaitMillis)
            {
                auto res = WaitForSingleObject(m_event, uint.max - 1);
                if (res != WAIT_TIMEOUT)
                    return res == WAIT_OBJECT_0;
                tmout -= maxWaitMillis;
            }
            auto ms = cast(uint)(tmout.total!"msecs");
            return WaitForSingleObject(m_event, ms) == WAIT_OBJECT_0;
    }

private:
        HANDLE m_event;
}
