/**
 * Contains the implementation for object monitors.
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2000 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.monitor_;

//debug=PRINTF;

///////////////////////////////////////////////////////////////////////////////
// Monitor
///////////////////////////////////////////////////////////////////////////////

// NOTE: The dtor callback feature is only supported for monitors that are not
//       supplied by the user.  The assumption is that any object with a user-
//       supplied monitor may have special storage or lifetime requirements and
//       that as a result, storing references to local objects within Monitor
//       may not be safe or desirable.  Thus, devt is only valid if impl is
//       null.

extern(C) void _d_setSameMutex(shared Object ownee, shared Object owner) nothrow
in
{
    assert(ownee.__monitor is null);
}
body
{
    auto m = cast(shared(Monitor)*) owner.__monitor;

    if (m is null)
    {
        _d_monitor_create(cast(Object) owner);
        m = cast(shared(Monitor)*) owner.__monitor;
    }

    auto i = m.impl;
    if (i is null)
    {
        atomicOp!("+=")(m.refs, cast(size_t)1);
        ownee.__monitor = owner.__monitor;
        return;
    }
    // If m.impl is set (ie. if this is a user-created monitor), assume
    // the monitor is garbage collected and simply copy the reference.
    ownee.__monitor = owner.__monitor;
}

extern (C) void _d_monitordelete(Object h, bool det)
{
    // det is true when the object is being destroyed deterministically (ie.
    // when it is explicitly deleted or is a scope object whose time is up).
    Monitor* m = getMonitor(h);

    if (m !is null)
    {
        IMonitor i = m.impl;
        if (i is null)
        {
            auto s = cast(shared(Monitor)*) m;
            if(!atomicOp!("-=")(s.refs, cast(size_t) 1))
            {
                _d_monitor_devt(m, h);
                _d_monitor_destroy(h);
                setMonitor(h, null);
            }
            return;
        }
        // NOTE: Since a monitor can be shared via setSameMutex it isn't safe
        //       to explicitly delete user-created monitors--there's no
        //       refcount and it may have multiple owners.
        /+
        if (det && (cast(void*) i) !is (cast(void*) h))
        {
            destroy(i);
            GC.free(cast(void*)i);
        }
        +/
        setMonitor(h, null);
    }
}

extern (C) void _d_monitorenter(Object h)
{
    Monitor* m = getMonitor(h);

    if (m is null)
    {
        _d_monitor_create(h);
        m = getMonitor(h);
    }

    IMonitor i = m.impl;

    if (i is null)
    {
        _d_monitor_lock(h);
        return;
    }
    i.lock();
}

extern (C) void _d_monitorexit(Object h)
{
    Monitor* m = getMonitor(h);
    IMonitor i = m.impl;

    if (i is null)
    {
        _d_monitor_unlock(h);
        return;
    }
    i.unlock();
}

extern (C) void _d_monitor_devt(Monitor* m, Object h)
{
    if (m.devt.length)
    {
        DEvent[] devt;

        synchronized (h)
        {
            devt = m.devt;
            m.devt = null;
        }
        foreach (v; devt)
        {
            if (v)
                v(h);
        }
        free(devt.ptr);
    }
}

extern (C) void rt_attachDisposeEvent(Object h, DEvent e)
{
    synchronized (h)
    {
        Monitor* m = getMonitor(h);
        assert(m.impl is null);

        foreach (ref v; m.devt)
        {
            if (v is null || v == e)
            {
                v = e;
                return;
            }
        }

        auto len = m.devt.length + 4; // grow by 4 elements
        auto pos = m.devt.length;     // insert position
        auto p = realloc(m.devt.ptr, DEvent.sizeof * len);
        import core.exception : onOutOfMemoryError;
        if (!p)
            onOutOfMemoryError();
        m.devt = (cast(DEvent*)p)[0 .. len];
        m.devt[pos+1 .. len] = null;
        m.devt[pos] = e;
    }
}

extern (C) void rt_detachDisposeEvent(Object h, DEvent e)
{
    synchronized (h)
    {
        Monitor* m = getMonitor(h);
        assert(m.impl is null);

        foreach (p, v; m.devt)
        {
            if (v == e)
            {
                memmove(&m.devt[p],
                        &m.devt[p+1],
                        (m.devt.length - p - 1) * DEvent.sizeof);
                m.devt[$ - 1] = null;
                return;
            }
        }
    }
}

nothrow:

private
{
    debug(PRINTF) import core.stdc.stdio;
    import core.stdc.stdlib;
    import core.stdc.string;
    import core.atomic;

    version( CRuntime_Glibc )
    {
        version = USE_PTHREADS;
    }
    else version( FreeBSD )
    {
        version = USE_PTHREADS;
    }
    else version( OSX )
    {
        version = USE_PTHREADS;
    }
    else version( Solaris )
    {
        version = USE_PTHREADS;
    }
    else version( CRuntime_Bionic )
    {
        version = USE_PTHREADS;
    }

    // This is what the monitor reference in Object points to
    alias Object.Monitor        IMonitor;
    alias void delegate(Object) DEvent;

    version( Windows )
    {
        version (CRuntime_DigitalMars)
        {
            pragma(lib, "snn.lib");
        }
        else version (CRuntime_Microsoft)
        {
            pragma(lib, "libcmt.lib");
            pragma(lib, "oldnames.lib");
        }
        import core.sys.windows.windows;

        struct Monitor
        {
            IMonitor impl; // for user-level monitors
            DEvent[] devt; // for internal monitors
            size_t   refs; // reference count
            CRITICAL_SECTION mon;
        }
    }
    else version( USE_PTHREADS )
    {
        import core.sys.posix.pthread;

        struct Monitor
        {
            IMonitor impl; // for user-level monitors
            DEvent[] devt; // for internal monitors
            size_t   refs; // reference count
            pthread_mutex_t mon;
        }
    }
    else
    {
        static assert(0, "Unsupported platform");
    }

    Monitor* getMonitor(Object h) pure
    {
        return cast(Monitor*) h.__monitor;
    }

    void setMonitor(Object h, Monitor* m) pure
    {
        h.__monitor = m;
    }

    static __gshared int inited;
}


/* =============================== Win32 ============================ */

version( Windows )
{
    static __gshared CRITICAL_SECTION _monitor_critsec;

    extern (C) void _STI_monitor_staticctor()
    {
        debug(PRINTF) printf("+_STI_monitor_staticctor()\n");
        if (!inited)
        {
            InitializeCriticalSection(&_monitor_critsec);
            inited = 1;
        }
        debug(PRINTF) printf("-_STI_monitor_staticctor()\n");
    }

    extern (C) void _STD_monitor_staticdtor()
    {
        debug(PRINTF) printf("+_STI_monitor_staticdtor() - d\n");
        if (inited)
        {
            inited = 0;
            DeleteCriticalSection(&_monitor_critsec);
        }
        debug(PRINTF) printf("-_STI_monitor_staticdtor() - d\n");
    }

    extern (C) void _d_monitor_create(Object h)
    {
        /*
         * NOTE: Assume this is only called when h.__monitor is null prior to the
         * call.  However, please note that another thread may call this function
         * at the same time, so we can not assert this here.  Instead, try and
         * create a lock, and if one already exists then forget about it.
         */

        debug(PRINTF) printf("+_d_monitor_create(%p)\n", h);
        assert(h);
        Monitor *cs;
        EnterCriticalSection(&_monitor_critsec);
        if (!h.__monitor)
        {
            cs = cast(Monitor *)calloc(Monitor.sizeof, 1);
            assert(cs);
            InitializeCriticalSection(&cs.mon);
            setMonitor(h, cs);
            cs.refs = 1;
            cs = null;
        }
        LeaveCriticalSection(&_monitor_critsec);
        if (cs)
            free(cs);
        debug(PRINTF) printf("-_d_monitor_create(%p)\n", h);
    }

    extern (C) void _d_monitor_destroy(Object h)
    {
        debug(PRINTF) printf("+_d_monitor_destroy(%p)\n", h);
        assert(h && h.__monitor && !getMonitor(h).impl);
        DeleteCriticalSection(&getMonitor(h).mon);
        free(h.__monitor);
        setMonitor(h, null);
        debug(PRINTF) printf("-_d_monitor_destroy(%p)\n", h);
    }

    extern (C) void _d_monitor_lock(Object h)
    {
        debug(PRINTF) printf("+_d_monitor_acquire(%p)\n", h);
        assert(h && h.__monitor && !getMonitor(h).impl);
        EnterCriticalSection(&getMonitor(h).mon);
        debug(PRINTF) printf("-_d_monitor_acquire(%p)\n", h);
    }

    extern (C) void _d_monitor_unlock(Object h)
    {
        debug(PRINTF) printf("+_d_monitor_release(%p)\n", h);
        assert(h && h.__monitor && !getMonitor(h).impl);
        LeaveCriticalSection(&getMonitor(h).mon);
        debug(PRINTF) printf("-_d_monitor_release(%p)\n", h);
    }
}

/* =============================== linux ============================ */

version( USE_PTHREADS )
{
    // Includes attribute fixes from David Friedman's GDC port
    static __gshared pthread_mutex_t _monitor_critsec;
    static __gshared pthread_mutexattr_t _monitors_attr;

    extern (C) void _STI_monitor_staticctor()
    {
        if (!inited)
        {
            pthread_mutexattr_init(&_monitors_attr);
            pthread_mutexattr_settype(&_monitors_attr, PTHREAD_MUTEX_RECURSIVE);
            pthread_mutex_init(&_monitor_critsec, &_monitors_attr);
            inited = 1;
        }
    }

    extern (C) void _STD_monitor_staticdtor()
    {
        if (inited)
        {
            inited = 0;
            pthread_mutex_destroy(&_monitor_critsec);
            pthread_mutexattr_destroy(&_monitors_attr);
        }
    }

    extern (C) void _d_monitor_create(Object h)
    {
        /*
         * NOTE: Assume this is only called when h.__monitor is null prior to the
         * call.  However, please note that another thread may call this function
         * at the same time, so we can not assert this here.  Instead, try and
         * create a lock, and if one already exists then forget about it.
         */

        debug(PRINTF) printf("+_d_monitor_create(%p)\n", h);
        assert(h);
        Monitor *cs;
        pthread_mutex_lock(&_monitor_critsec);
        if (!h.__monitor)
        {
            cs = cast(Monitor *)calloc(Monitor.sizeof, 1);
            assert(cs);
            pthread_mutex_init(&cs.mon, &_monitors_attr);
            setMonitor(h, cs);
            cs.refs = 1;
            cs = null;
        }
        pthread_mutex_unlock(&_monitor_critsec);
        if (cs)
            free(cs);
        debug(PRINTF) printf("-_d_monitor_create(%p)\n", h);
    }

    extern (C) void _d_monitor_destroy(Object h)
    {
        debug(PRINTF) printf("+_d_monitor_destroy(%p)\n", h);
        assert(h && h.__monitor && !getMonitor(h).impl);
        pthread_mutex_destroy(&getMonitor(h).mon);
        free(h.__monitor);
        setMonitor(h, null);
        debug(PRINTF) printf("-_d_monitor_destroy(%p)\n", h);
    }

    extern (C) void _d_monitor_lock(Object h)
    {
        debug(PRINTF) printf("+_d_monitor_acquire(%p)\n", h);
        assert(h && h.__monitor && !getMonitor(h).impl);
        pthread_mutex_lock(&getMonitor(h).mon);
        debug(PRINTF) printf("-_d_monitor_acquire(%p)\n", h);
    }

    extern (C) void _d_monitor_unlock(Object h)
    {
        debug(PRINTF) printf("+_d_monitor_release(%p)\n", h);
        assert(h && h.__monitor && !getMonitor(h).impl);
        pthread_mutex_unlock(&getMonitor(h).mon);
        debug(PRINTF) printf("-_d_monitor_release(%p)\n", h);
    }
}
