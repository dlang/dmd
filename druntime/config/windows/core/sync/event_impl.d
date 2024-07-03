module core.sync.event_impl;

import core.internal.abort : abort;
import core.sys.windows.basetsd /+: HANDLE +/;
import core.sys.windows.winerror /+: WAIT_TIMEOUT +/;
import core.sys.windows.winbase /+: CreateEvent, CloseHandle, SetEvent, ResetEvent,
    WaitForSingleObject, INFINITE, WAIT_OBJECT_0+/;
import core.time;

package:

nothrow @nogc:

alias EventHandler = HANDLE;

bool initalized(in EventHandler h) { return h !is null; }

EventHandler create(bool manualReset, bool initialState)
{
    HANDLE m_event = CreateEvent(null, manualReset, initialState, null);
    m_event || abort("Error: CreateEvent failed.");

    return m_event;
}

void destroy(ref EventHandler m_event)
{
    CloseHandle(m_event);
    m_event = null;
}

void set(EventHandler m_event)
{
    SetEvent(m_event);
}

void reset(EventHandler m_event)
{
    ResetEvent(m_event);
}

bool wait(EventHandler m_event)
{
    return m_event && WaitForSingleObject(m_event, INFINITE) == WAIT_OBJECT_0;
}

bool wait(EventHandler m_event, Duration tmout)
{
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
