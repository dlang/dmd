/**
 * Contains the implementation for object monitors.
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
#if _WIN32

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include <windows.h>

#include "mars.h"

// This is what the monitor reference in Object points to
typedef struct Monitor
{
    void*  impl; // for user-level monitors
    Array  devt; // for internal monitors
    size_t refs; // reference count
    CRITICAL_SECTION mon;

} Monitor;

#define MONPTR(h)       (&((Monitor *)(h)->monitor)->mon)

extern volatile int inited_monitor_stuff;

/* =============================== Win32 ============================ */

extern CRITICAL_SECTION _monitor_critsec;

void _STI_monitor_staticctor()
{
    //printf("+_STI_monitor_staticctor() - c\n");
    if (!inited_monitor_stuff)
    {   InitializeCriticalSection(&_monitor_critsec);
        inited_monitor_stuff = 1;
    }
    //printf("-_STI_monitor_staticctor() - c\n");
}

void _STD_monitor_staticdtor()
{
    //printf("+_STI_monitor_staticdtor() - c\n");
    if (inited_monitor_stuff)
    {   inited_monitor_stuff = 0;
        DeleteCriticalSection(&_monitor_critsec);
    }
    //printf("-_STI_monitor_staticdtor() - c\n");
}

void _d_monitor_create(Object *h)
{
    /*
     * NOTE: Assume this is only called when h->monitor is null prior to the
     * call.  However, please note that another thread may call this function
     * at the same time, so we can not assert this here.  Instead, try and
     * create a lock, and if one already exists then forget about it.
     */

    //printf("+_d_monitor_create(%p)\n", h);
    assert(h);
    Monitor *cs = NULL;
    EnterCriticalSection(&_monitor_critsec);
    if (!h->monitor)
    {
        cs = (Monitor *)calloc(sizeof(Monitor), 1);
        assert(cs);
        InitializeCriticalSection(&cs->mon);
        h->monitor = (void *)cs;
        cs->refs = 1;
        cs = NULL;
    }
    LeaveCriticalSection(&_monitor_critsec);
    if (cs)
        free(cs);
    //printf("-_d_monitor_create(%p)\n", h);
}

void _d_monitor_destroy(Object *h)
{
    //printf("+_d_monitor_destroy(%p)\n", h);
    assert(h && h->monitor && !(((Monitor*)h->monitor)->impl));
    DeleteCriticalSection(MONPTR(h));
    free((void *)h->monitor);
    h->monitor = NULL;
    //printf("-_d_monitor_destroy(%p)\n", h);
}

int _d_monitor_lock(Object *h)
{
    //printf("+_d_monitor_acquire(%p)\n", h);
    assert(h && h->monitor && !(((Monitor*)h->monitor)->impl));
    EnterCriticalSection(MONPTR(h));
    //printf("-_d_monitor_acquire(%p)\n", h);
}

void _d_monitor_unlock(Object *h)
{
    //printf("+_d_monitor_release(%p)\n", h);
    assert(h && h->monitor && !(((Monitor*)h->monitor)->impl));
    LeaveCriticalSection(MONPTR(h));
    //printf("-_d_monitor_release(%p)\n", h);
}

#endif

