module core.sync.event_impl;

import core.internal.abort : abort;
import core.sys.posix.pthread;
import core.sys.posix.sys.types;
import core.sys.posix.time;
import core.time;

package:

nothrow @nogc:

struct EventHandler
{
    pthread_mutex_t m_mutex;
    pthread_cond_t m_cond;
    bool initalized;
    bool m_state;
    bool m_manualReset;
}

EventHandler create(bool manualReset, bool initialState)
{
    EventHandler h;

    pthread_mutex_init(cast(pthread_mutex_t*) &(h.m_mutex), null) == 0 ||
        abort("Error: pthread_mutex_init failed.");

    static if ( is( typeof( pthread_condattr_setclock ) ) )
    {
        pthread_condattr_t attr = void;
        pthread_condattr_init(&attr) == 0 ||
            abort("Error: pthread_condattr_init failed.");
        pthread_condattr_setclock(&attr, CLOCK_MONOTONIC) == 0 ||
            abort("Error: pthread_condattr_setclock failed.");
        pthread_cond_init(&(h.m_cond), &attr) == 0 ||
            abort("Error: pthread_cond_init failed.");
        pthread_condattr_destroy(&attr) == 0 ||
            abort("Error: pthread_condattr_destroy failed.");
    }
    else
    {
        pthread_cond_init(&(h.m_cond), null) == 0 ||
            abort("Error: pthread_cond_init failed.");
    }

    h.m_state = initialState;
    h.m_manualReset = manualReset;
    h.initalized = true;

    return h;
}

void destroy(ref EventHandler h)
{
    pthread_mutex_destroy(&(h.m_mutex)) == 0 ||
        abort("Error: pthread_mutex_destroy failed.");

    pthread_cond_destroy(&(h.m_cond)) == 0 ||
        abort("Error: pthread_cond_destroy failed.");

    h.initalized = false;
}

void set(ref EventHandler h)
{
    h.mutexLock;
    h.m_state = true;
    pthread_cond_broadcast(&(h.m_cond));
    h.mutexUnlock;
}

void reset(ref EventHandler h)
{
    h.mutexLock;
    h.m_state = false;
    h.mutexUnlock;
}

bool wait(ref EventHandler h)
{
    return h.wait(Duration.max);
}

bool wait(ref EventHandler h, Duration tmout)
{
    h.mutexLock;

    int result = 0;
    if (!h.m_state)
    {
        if (tmout == Duration.max)
        {
            result = pthread_cond_wait(&(h.m_cond), &(h.m_mutex));
        }
        else
        {
            import core.sync.config;

            timespec t = void;
            mktspec(t, tmout);

            result = pthread_cond_timedwait(&(h.m_cond), &(h.m_mutex), &t);
        }
    }
    if (result == 0 && !h.m_manualReset)
        h.m_state = false;

    h.mutexUnlock;

    return result == 0;
}

private void mutexLock(ref EventHandler h) { pthread_mutex_lock(&(h.m_mutex)); }
private void mutexUnlock(ref EventHandler h) { pthread_mutex_unlock(&(h.m_mutex)); }
