/**
 * This module contains a minimal garbage collector implementation according to
 * published requirements.  This library is mostly intended to serve as an
 * example, but it is usable in applications which do not rely on a garbage
 * collector to clean up memory (ie. when dynamic array resizing is not used,
 * and all memory allocated with 'new' is freed deterministically with
 * 'delete').
 *
 * Please note that block attribute data must be tracked, or at a minimum, the
 * FINALIZE bit must be tracked for any allocated memory block because calling
 * rt_finalize on a non-object block can result in an access violation.  In the
 * allocator below, this tracking is done via a leading uint bitmask.  A real
 * allocator may do better to store this data separately, similar to the basic
 * GC.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module gc.gc;

private
{
   import core.stdc.stdlib;
   import core.stdc.stdio;

   enum BlkAttr : uint
    {
        FINALIZE    = 0b0000_0001,
        NO_SCAN     = 0b0000_0010,
        NO_MOVE     = 0b0000_0100,
        APPENDABLE  = 0b0000_1000,
        ALL_BITS    = 0b1111_1111
    }

    struct BlkInfo
    {
        void*  base;
        size_t size;
        uint   attr;
    }

    extern (C) void thread_init();
    extern (C) void onOutOfMemoryError();

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

        pthis.gc_isCollecting = &gc_isCollecting;
        pthis.gc_getAttr = &gc_getAttr;
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

    __gshared void** roots  = null;
    __gshared size_t nroots = 0;

    struct Range
    {
        void*  pos;
        size_t len;
    }

    __gshared Range* ranges  = null;
    __gshared size_t nranges = 0;
}

extern (C) void gc_init()
{
    // NOTE: The GC must initialize the thread library before its first
    //       collection, and always before returning from gc_init().
    thread_init();
    initProxy();
}

extern (C) void gc_term()
{
    free( roots );
    free( ranges );
}

extern (C) void gc_enable()
{
    if( proxy is null )
        return;
    return proxy.gc_enable();
}

extern (C) void gc_disable()
{
    if( proxy is null )
        return;
    return proxy.gc_disable();
}

extern (C) void gc_collect()
{
    if( proxy is null )
        return;
    return proxy.gc_collect();
}

extern (C) void gc_minimize()
{
    if( proxy is null )
        return;
    return proxy.gc_minimize();
}

extern (C) bool gc_isCollecting( void* p )
{
    if( proxy is null )
        return false;
    return proxy.gc_isCollecting( p );
}

extern (C) uint gc_getAttr( void* p )
{
    if( proxy is null )
        return 0;
    return proxy.gc_getAttr( p );
}

extern (C) uint gc_setAttr( void* p, uint a )
{
    if( proxy is null )
        return 0;
    return proxy.gc_setAttr( p, a );
}

extern (C) uint gc_clrAttr( void* p, uint a )
{
    if( proxy is null )
        return 0;
    return proxy.gc_clrAttr( p, a );
}

extern (C) void* gc_malloc( size_t sz, uint ba = 0 )
{
    if( proxy is null )
    {
        void* p = malloc( sz );

        if( sz && p is null )
            onOutOfMemoryError();
        return p;
    }
    return proxy.gc_malloc( sz, ba );
}

extern (C) BlkInfo gc_qalloc( size_t sz, uint ba = 0 )
{
    if( proxy is null )
    {
        BlkInfo retval;
        retval.base = gc_malloc(sz, ba);
        retval.size = sz;
        retval.attr = ba;
        return retval;
    }
    return proxy.gc_qalloc( sz, ba );
}

extern (C) void* gc_calloc( size_t sz, uint ba = 0 )
{
    if( proxy is null )
    {
        void* p = calloc( 1, sz );

        if( sz && p is null )
            onOutOfMemoryError();
        return p;
    }
    return proxy.gc_calloc( sz, ba );
}

extern (C) void* gc_realloc( void* p, size_t sz, uint ba = 0 )
{
    if( proxy is null )
    {
        p = realloc( p, sz );

        if( sz && p is null )
            onOutOfMemoryError();
        return p;
    }
    return proxy.gc_realloc( p, sz, ba );
}

extern (C) size_t gc_extend( void* p, size_t mx, size_t sz )
{
    if( proxy is null )
        return 0;
    return proxy.gc_extend( p, mx, sz );
}

extern (C) size_t gc_reserve( size_t sz )
{
    if( proxy is null )
        return 0;
    return proxy.gc_reserve( sz );
}

extern (C) void gc_free( void* p )
{
    if( proxy is null )
        return free( p );
    return proxy.gc_free( p );
}

extern (C) void* gc_addrOf( void* p )
{
    if( proxy is null )
        return null;
    return proxy.gc_addrOf( p );
}

extern (C) size_t gc_sizeOf( void* p )
{
    if( proxy is null )
        return 0;
    return proxy.gc_sizeOf( p );
}

extern (C) BlkInfo gc_query( void* p )
{
    if( proxy is null )
        return BlkInfo.init;
    return proxy.gc_query( p );
}

extern (C) void gc_addRoot( void* p )
{
    if( proxy is null )
    {
        void** r = cast(void**) realloc( roots,
                                         (nroots+1) * roots[0].sizeof );
        if( r is null )
            onOutOfMemoryError();
        r[nroots++] = p;
        roots = r;
        return;
    }
    return proxy.gc_addRoot( p );
}

extern (C) void gc_addRange( void* p, size_t sz )
{
    //printf("gcstub::gc_addRange() proxy = %p\n", proxy);
    if( proxy is null )
    {
        Range* r = cast(Range*) realloc( ranges,
                                         (nranges+1) * ranges[0].sizeof );
        if( r is null )
            onOutOfMemoryError();
        r[nranges].pos = p;
        r[nranges].len = sz;
        ranges = r;
        ++nranges;
        return;
    }
    return proxy.gc_addRange( p, sz );
}

extern (C) void gc_removeRoot( void *p )
{
    if( proxy is null )
    {
        for( size_t i = 0; i < nroots; ++i )
        {
            if( roots[i] is p )
            {
                roots[i] = roots[--nroots];
                return;
            }
        }
        assert( false );
    }
    return proxy.gc_removeRoot( p );
}

extern (C) void gc_removeRange( void *p )
{
    if( proxy is null )
    {
        for( size_t i = 0; i < nranges; ++i )
        {
            if( ranges[i].pos is p )
            {
                ranges[i] = ranges[--nranges];
                return;
            }
        }
        assert( false );
    }
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
    foreach( r; roots[0 .. nroots] )
        proxy.gc_addRoot( r );
    foreach( r; ranges[0 .. nranges] )
        proxy.gc_addRange( r.pos, r.len );
}

export extern (C) void gc_clrProxy()
{
    foreach( r; ranges[0 .. nranges] )
        proxy.gc_removeRange( r.pos );
    foreach( r; roots[0 .. nroots] )
        proxy.gc_removeRoot( r );
    proxy = null;
}
