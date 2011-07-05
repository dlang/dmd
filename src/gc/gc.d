/**
 * Contains the external GC interface.
 *
 * Copyright: Copyright Digital Mars 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module gc.gc;

private
{
    import gc.gcx;
    import gc.gcstats;
    import core.stdc.stdlib;

    version = GCCLASS;

    version( GCCLASS )
        alias GC gc_t;
    else
        alias GC* gc_t;

    __gshared gc_t _gc;

    extern (C) void thread_init();

    struct Proxy
    {
        extern (C) void function() gc_enable;
        extern (C) void function() gc_disable;
        extern (C) void function() gc_collect;
        extern (C) void function() gc_minimize;

        extern (C) bool function(void*) gc_isCollecting;
        extern (C) uint function(void*) gc_getAttr;
        extern (C) uint function(void*, uint) gc_setAttr;
        extern (C) uint function(void*, uint) gc_clrAttr;

        extern (C) void*   function(size_t, uint) gc_malloc;
        extern (C) BlkInfo function(size_t, uint) gc_qalloc;
        extern (C) void*   function(size_t, uint) gc_calloc;
        extern (C) void*   function(void*, size_t, uint ba) gc_realloc;
        extern (C) size_t  function(void*, size_t, size_t) gc_extend;
        extern (C) size_t  function(size_t) gc_reserve;
        extern (C) void    function(void*) gc_free;

        extern (C) void*   function(void*) gc_addrOf;
        extern (C) size_t  function(void*) gc_sizeOf;

        extern (C) BlkInfo function(void*) gc_query;

        extern (C) void function(void*) gc_addRoot;
        extern (C) void function(void*, size_t) gc_addRange;

        extern (C) void function(void*) gc_removeRoot;
        extern (C) void function(void*) gc_removeRange;
    }

    __gshared Proxy  pthis;
    __gshared Proxy* proxy;

    void initProxy()
    {
        pthis.gc_enable = &gc_enable;
        pthis.gc_disable = &gc_disable;
        pthis.gc_collect = &gc_collect;
        pthis.gc_minimize = &gc_minimize;

        pthis.gc_getAttr = &gc_getAttr;
        pthis.gc_isCollecting = &gc_isCollecting;
        pthis.gc_setAttr = &gc_setAttr;
        pthis.gc_clrAttr = &gc_clrAttr;

        pthis.gc_malloc = &gc_malloc;
        pthis.gc_qalloc = &gc_qalloc;
        pthis.gc_calloc = &gc_calloc;
        pthis.gc_realloc = &gc_realloc;
        pthis.gc_extend = &gc_extend;
        pthis.gc_reserve = &gc_reserve;
        pthis.gc_free = &gc_free;

        pthis.gc_addrOf = &gc_addrOf;
        pthis.gc_sizeOf = &gc_sizeOf;

        pthis.gc_query = &gc_query;

        pthis.gc_addRoot = &gc_addRoot;
        pthis.gc_addRange = &gc_addRange;

        pthis.gc_removeRoot = &gc_removeRoot;
        pthis.gc_removeRange = &gc_removeRange;
    }
}

extern (C) void gc_init()
{
    version (GCCLASS)
    {   void* p;
        ClassInfo ci = GC.classinfo;

        p = malloc(ci.init.length);
        (cast(byte*)p)[0 .. ci.init.length] = ci.init[];
        _gc = cast(GC)p;
    }
    else
    {
        _gc = cast(GC*) calloc(1, GC.sizeof);
    }
    _gc.initialize();
    // NOTE: The GC must initialize the thread library
    //       before its first collection.
    thread_init();
    initProxy();
}

extern (C) void gc_term()
{
    // NOTE: There may be daemons threads still running when this routine is
    //       called.  If so, cleaning memory out from under then is a good
    //       way to make them crash horribly.  This probably doesn't matter
    //       much since the app is supposed to be shutting down anyway, but
    //       I'm disabling cleanup for now until I can think about it some
    //       more.
    //
    // NOTE: Due to popular demand, this has been re-enabled.  It still has
    //       the problems mentioned above though, so I guess we'll see.
    _gc.fullCollectNoStack(); // not really a 'collect all' -- still scans
                              // static data area, roots, and ranges.
    _gc.Dtor();
}

extern (C) void gc_enable()
{
    if( proxy is null )
        return _gc.enable();
    return proxy.gc_enable();
}

extern (C) void gc_disable()
{
    if( proxy is null )
        return _gc.disable();
    return proxy.gc_disable();
}

extern (C) void gc_collect()
{
    if( proxy is null )
    {
        _gc.fullCollect();
        return;
    }
    return proxy.gc_collect();
}

extern(C) bool gc_isCollecting(void *p)
{
    if( proxy is null )
        return _gc.isCollecting(p);
    return proxy.gc_isCollecting(p);
}


extern (C) void gc_minimize()
{
    if( proxy is null )
        return _gc.minimize();
    return proxy.gc_minimize();
}

extern (C) uint gc_getAttr( void* p )
{
    if( proxy is null )
        return _gc.getAttr( p );
    return proxy.gc_getAttr( p );
}

extern (C) uint gc_setAttr( void* p, uint a )
{
    if( proxy is null )
        return _gc.setAttr( p, a );
    return proxy.gc_setAttr( p, a );
}

extern (C) uint gc_clrAttr( void* p, uint a )
{
    if( proxy is null )
        return _gc.clrAttr( p, a );
    return proxy.gc_clrAttr( p, a );
}

extern (C) void* gc_malloc( size_t sz, uint ba = 0 )
{
    if( proxy is null )
        return _gc.malloc( sz, ba );
    return proxy.gc_malloc( sz, ba );
}

extern (C) BlkInfo gc_qalloc( size_t sz, uint ba = 0 )
{
    if( proxy is null )
    {
        BlkInfo retval;
        retval.base = _gc.malloc( sz, ba, &retval.size );
        retval.attr = ba;
        return retval;
    }
    return proxy.gc_qalloc( sz, ba );
}

extern (C) void* gc_calloc( size_t sz, uint ba = 0 )
{
    if( proxy is null )
        return _gc.calloc( sz, ba );
    return proxy.gc_calloc( sz, ba );
}

extern (C) void* gc_realloc( void* p, size_t sz, uint ba = 0 )
{
    if( proxy is null )
        return _gc.realloc( p, sz, ba );
    return proxy.gc_realloc( p, sz, ba );
}

extern (C) size_t gc_extend( void* p, size_t mx, size_t sz )
{
    if( proxy is null )
        return _gc.extend( p, mx, sz );
    return proxy.gc_extend( p, mx, sz );
}

extern (C) size_t gc_reserve( size_t sz )
{
    if( proxy is null )
        return _gc.reserve( sz );
    return proxy.gc_reserve( sz );
}

extern (C) void gc_free( void* p )
{
    if( proxy is null )
        return _gc.free( p );
    return proxy.gc_free( p );
}

extern (C) void* gc_addrOf( void* p )
{
    if( proxy is null )
        return _gc.addrOf( p );
    return proxy.gc_addrOf( p );
}

extern (C) size_t gc_sizeOf( void* p )
{
    if( proxy is null )
        return _gc.sizeOf( p );
    return proxy.gc_sizeOf( p );
}

extern (C) BlkInfo gc_query( void* p )
{
    if( proxy is null )
        return _gc.query( p );
    return proxy.gc_query( p );
}

// NOTE: This routine is experimental.  The stats or function name may change
//       before it is made officially available.
extern (C) GCStats gc_stats()
{
    if( proxy is null )
    {
        GCStats stats = void;
        _gc.getStats( stats );
        return stats;
    }
    // TODO: Add proxy support for this once the layout of GCStats is
    //       finalized.
    //return proxy.gc_stats();
    return GCStats.init;
}

extern (C) void gc_addRoot( void* p )
{
    if( proxy is null )
        return _gc.addRoot( p );
    return proxy.gc_addRoot( p );
}

extern (C) void gc_addRange( void* p, size_t sz )
{
    if( proxy is null )
        return _gc.addRange( p, sz );
    return proxy.gc_addRange( p, sz );
}

extern (C) void gc_removeRoot( void* p )
{
    if( proxy is null )
        return _gc.removeRoot( p );
    return proxy.gc_removeRoot( p );
}

extern (C) void gc_removeRange( void* p )
{
    if( proxy is null )
        return _gc.removeRange( p );
    return proxy.gc_removeRange( p );
}

extern (C) Proxy* gc_getProxy()
{
    return &pthis;
}

export extern (C) void gc_setProxy( Proxy* p )
{
    if( proxy !is null )
    {
        // TODO: Decide if this is an error condition.
    }
    proxy = p;
    foreach( r; _gc.rootIter )
        proxy.gc_addRoot( r );
    foreach( r; _gc.rangeIter )
        proxy.gc_addRange( r.pbot, r.ptop - r.pbot );
}

export extern (C) void gc_clrProxy()
{
    foreach( r; _gc.rangeIter )
        proxy.gc_removeRange( r.pbot );
    foreach( r; _gc.rootIter )
        proxy.gc_removeRoot( r );
    proxy = null;
}
