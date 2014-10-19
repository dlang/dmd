/**
 * Contains the external GC interface.
 *
 * Copyright: Copyright Digital Mars 2005 - 2013.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2005 - 2013.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module gc.proxy;

import gc.gc;
import gc.stats;
import core.stdc.stdlib;

private
{
    version = GCCLASS;

    version( GCCLASS )
        alias GC gc_t;
    else
        alias GC* gc_t;

    __gshared gc_t _gc;

    static import core.memory;
    alias BlkInfo = core.memory.GC.BlkInfo;

    extern (C) void thread_init();
    extern (C) void thread_term();

    struct Proxy
    {
        extern (C)
        {
            void function() gc_enable;
            void function() gc_disable;
        nothrow:
            void function() gc_collect;
            void function() gc_minimize;

            uint function(void*) gc_getAttr;
            uint function(void*, uint) gc_setAttr;
            uint function(void*, uint) gc_clrAttr;

            void*   function(size_t, uint, const TypeInfo) gc_malloc;
            BlkInfo function(size_t, uint, const TypeInfo) gc_qalloc;
            void*   function(size_t, uint, const TypeInfo) gc_calloc;
            void*   function(void*, size_t, uint ba, const TypeInfo) gc_realloc;
            size_t  function(void*, size_t, size_t, const TypeInfo) gc_extend;
            size_t  function(size_t) gc_reserve;
            void    function(void*) gc_free;

            void*   function(void*) gc_addrOf;
            size_t  function(void*) gc_sizeOf;

            BlkInfo function(void*) gc_query;

            void function(void*) gc_addRoot;
            void function(void*, size_t, const TypeInfo ti) gc_addRange;

            void function(void*) gc_removeRoot;
            void function(void*) gc_removeRange;
            void function(in void[]) gc_runFinalizers;
        }
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
        pthis.gc_runFinalizers = &gc_runFinalizers;
    }
}

extern (C)
{

    void gc_init()
    {
        version (GCCLASS)
        {   void* p;
            ClassInfo ci = typeid(GC);

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

    void gc_term()
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
        thread_term();

        _gc.Dtor();
        free(cast(void*)_gc);
        _gc = null;
    }

    void gc_enable()
    {
        if( proxy is null )
            return _gc.enable();
        return proxy.gc_enable();
    }

    void gc_disable()
    {
        if( proxy is null )
            return _gc.disable();
        return proxy.gc_disable();
    }

    void gc_collect() nothrow
    {
        if( proxy is null )
        {
            _gc.fullCollect();
            return;
        }
        return proxy.gc_collect();
    }

    void gc_minimize() nothrow
    {
        if( proxy is null )
            return _gc.minimize();
        return proxy.gc_minimize();
    }

    uint gc_getAttr( void* p ) nothrow
    {
        if( proxy is null )
            return _gc.getAttr( p );
        return proxy.gc_getAttr( p );
    }

    uint gc_setAttr( void* p, uint a ) nothrow
    {
        if( proxy is null )
            return _gc.setAttr( p, a );
        return proxy.gc_setAttr( p, a );
    }

    uint gc_clrAttr( void* p, uint a ) nothrow
    {
        if( proxy is null )
            return _gc.clrAttr( p, a );
        return proxy.gc_clrAttr( p, a );
    }

    void* gc_malloc( size_t sz, uint ba = 0, const TypeInfo ti = null ) nothrow
    {
        if( proxy is null )
            return _gc.malloc( sz, ba, null, ti );
        return proxy.gc_malloc( sz, ba, ti );
    }

    BlkInfo gc_qalloc( size_t sz, uint ba = 0, const TypeInfo ti = null ) nothrow
    {
        if( proxy is null )
        {
            BlkInfo retval;
            retval.base = _gc.malloc( sz, ba, &retval.size, ti );
            retval.attr = ba;
            return retval;
        }
        return proxy.gc_qalloc( sz, ba, ti );
    }

    void* gc_calloc( size_t sz, uint ba = 0, const TypeInfo ti = null ) nothrow
    {
        if( proxy is null )
            return _gc.calloc( sz, ba, null, ti );
        return proxy.gc_calloc( sz, ba, ti );
    }

    void* gc_realloc( void* p, size_t sz, uint ba = 0, const TypeInfo ti = null ) nothrow
    {
        if( proxy is null )
            return _gc.realloc( p, sz, ba, null, ti );
        return proxy.gc_realloc( p, sz, ba, ti );
    }

    size_t gc_extend( void* p, size_t mx, size_t sz, const TypeInfo ti = null ) nothrow
    {
        if( proxy is null )
            return _gc.extend( p, mx, sz, ti );
        return proxy.gc_extend( p, mx, sz,ti );
    }

    size_t gc_reserve( size_t sz ) nothrow
    {
        if( proxy is null )
            return _gc.reserve( sz );
        return proxy.gc_reserve( sz );
    }

    void gc_free( void* p ) nothrow
    {
        if( proxy is null )
            return _gc.free( p );
        return proxy.gc_free( p );
    }

    void* gc_addrOf( void* p ) nothrow
    {
        if( proxy is null )
            return _gc.addrOf( p );
        return proxy.gc_addrOf( p );
    }

    size_t gc_sizeOf( void* p ) nothrow
    {
        if( proxy is null )
            return _gc.sizeOf( p );
        return proxy.gc_sizeOf( p );
    }

    BlkInfo gc_query( void* p ) nothrow
    {
        if( proxy is null )
            return _gc.query( p );
        return proxy.gc_query( p );
    }

    // NOTE: This routine is experimental. The stats or function name may change
    //       before it is made officially available.
    GCStats gc_stats() nothrow
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

    void gc_addRoot( void* p ) nothrow
    {
        if( proxy is null )
            return _gc.addRoot( p );
        return proxy.gc_addRoot( p );
    }

    void gc_addRange( void* p, size_t sz, const TypeInfo ti = null ) nothrow
    {
        if( proxy is null )
            return _gc.addRange( p, sz, ti );
        return proxy.gc_addRange( p, sz, ti );
    }

    void gc_removeRoot( void* p ) nothrow
    {
        if( proxy is null )
            return _gc.removeRoot( p );
        return proxy.gc_removeRoot( p );
    }

    void gc_removeRange( void* p ) nothrow
    {
        if( proxy is null )
            return _gc.removeRange( p );
        return proxy.gc_removeRange( p );
    }

    void gc_runFinalizers( in void[] segment ) nothrow
    {
        if( proxy is null )
            return _gc.runFinalizers( segment );
        return proxy.gc_runFinalizers( segment );
    }

    Proxy* gc_getProxy() nothrow
    {
        return &pthis;
    }

    export
    {
        void gc_setProxy( Proxy* p )
        {
            if( proxy !is null )
            {
                // TODO: Decide if this is an error condition.
            }
            proxy = p;
            foreach (r; _gc.rootIter)
                proxy.gc_addRoot( r );

            foreach (r; _gc.rangeIter)
                proxy.gc_addRange( r.pbot, r.ptop - r.pbot, null );
        }

        void gc_clrProxy()
        {
            foreach (r; _gc.rangeIter)
                proxy.gc_removeRange( r.pbot );

            foreach (r; _gc.rootIter)
                proxy.gc_removeRoot( r );

            proxy = null;
        }
    }

}
