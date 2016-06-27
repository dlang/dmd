/**
 * Contains the external GC interface.
 *
 * Copyright: Copyright Digital Mars 2005 - 2016.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2005 - 2016.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module gc.proxy;

import gc.impl.conservative.gc;
import gc.impl.manual.gc;
import gc.config;
import gc.stats;
import gc.gcinterface;


private
{
    static import core.memory;
    alias BlkInfo = core.memory.GC.BlkInfo;

    extern (C) void thread_init();
    extern (C) void thread_term();

    __gshared GC currentGC;  //used for making the GC calls
    __gshared GC initialGC; //used to reset currentGC if gc_clrProxy was called

}


extern (C)
{

    void gc_init()
    {
        config.initialize();
        ManualGC.initialize(initialGC);
        ConservativeGC.initialize(initialGC);

        currentGC = initialGC;

        // NOTE: The GC must initialize the thread library
        //       before its first collection.
        thread_init();
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

        currentGC.collectNoStack(); // not really a 'collect all' -- still scans
                                    // static data area, roots, and ranges.

        thread_term();

        ManualGC.finalize();
        ConservativeGC.finalize();
    }

    void gc_enable()
    {
        currentGC.enable();
    }

    void gc_disable()
    {
        currentGC.disable();
    }

    void gc_collect() nothrow
    {
        currentGC.collect();
    }

    void gc_minimize() nothrow
    {
        currentGC.minimize();
    }

    uint gc_getAttr( void* p ) nothrow
    {
        return currentGC.getAttr(p);
    }

    uint gc_setAttr( void* p, uint a ) nothrow
    {
        return currentGC.setAttr(p, a);
    }

    uint gc_clrAttr( void* p, uint a ) nothrow
    {
        return currentGC.clrAttr(p, a);
    }

    void* gc_malloc( size_t sz, uint ba = 0, const TypeInfo ti = null ) nothrow
    {
        return currentGC.malloc(sz, ba, ti);
    }

    BlkInfo gc_qalloc( size_t sz, uint ba = 0, const TypeInfo ti = null ) nothrow
    {
        return currentGC.qalloc( sz, ba, ti );
    }

    void* gc_calloc( size_t sz, uint ba = 0, const TypeInfo ti = null ) nothrow
    {
        return currentGC.calloc( sz, ba, ti );
    }

    void* gc_realloc( void* p, size_t sz, uint ba = 0, const TypeInfo ti = null ) nothrow
    {
        return currentGC.realloc( p, sz, ba, ti );
    }

    size_t gc_extend( void* p, size_t mx, size_t sz, const TypeInfo ti = null ) nothrow
    {
        return currentGC.extend( p, mx, sz,ti );
    }

    size_t gc_reserve( size_t sz ) nothrow
    {
        return currentGC.reserve( sz );
    }

    void gc_free( void* p ) nothrow
    {
        return currentGC.free( p );
    }

    void* gc_addrOf( void* p ) nothrow
    {
        return currentGC.addrOf( p );
    }

    size_t gc_sizeOf( void* p ) nothrow
    {
        return currentGC.sizeOf( p );
    }

    BlkInfo gc_query( void* p ) nothrow
    {
        return currentGC.query( p );
    }

    // NOTE: This routine is experimental. The stats or function name may change
    //       before it is made officially available.
    GCStats gc_stats() nothrow
    {
        return currentGC.stats();
    }

    void gc_addRoot( void* p ) nothrow
    {
        return currentGC.addRoot( p );
    }

    void gc_addRange( void* p, size_t sz, const TypeInfo ti = null ) nothrow
    {
        return currentGC.addRange( p, sz, ti );
    }

    void gc_removeRoot( void* p ) nothrow
    {
        return currentGC.removeRoot( p );
    }

    void gc_removeRange( void* p ) nothrow
    {
        return currentGC.removeRange( p );
    }

    void gc_runFinalizers( in void[] segment ) nothrow
    {
        return currentGC.runFinalizers( segment );
    }

    bool gc_inFinalizer() nothrow
    {
        return currentGC.inFinalizer();
    }

    GC gc_getProxy() nothrow
    {
        return currentGC;
    }

    export
    {
        void gc_setProxy( GC newGC )
        {
            foreach(root; currentGC.rootIter)
            {
                newGC.addRoot(root);
            }

            foreach(range; currentGC.rangeIter)
            {
                newGC.addRange(range.pbot, range.ptop - range.pbot, range.ti);
            }

            currentGC = newGC;
        }

        void gc_clrProxy()
        {
            foreach(root; initialGC.rootIter)
            {
                currentGC.removeRoot(root);
            }

            foreach(range; initialGC.rangeIter)
            {
                currentGC.removeRange(range);
            }

            currentGC = initialGC;
        }
    }
}
