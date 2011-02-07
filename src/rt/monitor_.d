/**
 * Contains the implementation for object monitors.
 *
 * Copyright: Copyright Digital Mars 2000 - 2011.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2000 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.monitor_;

//debug=PRINTF;

private
{
    debug(PRINTF) import core.stdc.stdio;
    import core.stdc.stdlib;

    version( linux )
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

    // This is what the monitor reference in Object points to
    alias Object.Monitor        IMonitor;
    alias void delegate(Object) DEvent;

    version( Windows )
    {
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

    Monitor* getMonitor(Object h)
    {
        return cast(Monitor*) h.__monitor;
    }

    void setMonitor(Object h, Monitor* m)
    {
        h.__monitor = m;
    }

    static __gshared int inited;
}


/* =============================== Win32 ============================ */

version( Windows )
{
    /+
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
    +/
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

