/**
 * Contains the Windows implementation for object monitors.
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/_monitor.c)
 */

#if _WIN32 /* and Windows 64 */

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

static volatile int inited;

/* =============================== Win32 ============================ */

static CRITICAL_SECTION _monitor_critsec;

void _STI_monitor_staticctor()
{
    if (!inited)
    {   InitializeCriticalSection(&_monitor_critsec);
        inited = 1;
    }
}

void _STD_monitor_staticdtor()
{
    if (inited)
    {   inited = 0;
        DeleteCriticalSection(&_monitor_critsec);
    }
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
    Monitor *cs = NULL;
    assert(h);
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

void _d_monitor_lock(Object *h)
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

