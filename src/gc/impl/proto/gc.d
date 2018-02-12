
module gc.impl.proto.gc;

import gc.config;
import gc.gcinterface;

import rt.util.container.array;

import cstdlib = core.stdc.stdlib : calloc, free, malloc, realloc;
static import core.memory;

extern (C) void onOutOfMemoryError(void* pretend_sideffect = null) @trusted pure nothrow @nogc; /* dmd @@@BUG11461@@@ */

private
{
    extern (C) void gc_init_nothrow() nothrow @nogc;
    extern (C) void gc_term();

    extern (C) void gc_enable() nothrow;
    extern (C) void gc_disable() nothrow;

    extern (C) void*    gc_malloc( size_t sz, uint ba = 0, const TypeInfo = null ) pure nothrow;
    extern (C) void*    gc_calloc( size_t sz, uint ba = 0, const TypeInfo = null ) pure nothrow;
    extern (C) BlkInfo gc_qalloc( size_t sz, uint ba = 0, const TypeInfo = null ) pure nothrow;
    extern (C) void*    gc_realloc( void* p, size_t sz, uint ba = 0, const TypeInfo = null ) pure nothrow;
    extern (C) size_t   gc_reserve( size_t sz ) nothrow;

    extern (C) void gc_addRange( void* p, size_t sz, const TypeInfo ti = null ) nothrow @nogc;
    extern (C) void gc_addRoot( void* p ) nothrow @nogc;
}

class ProtoGC : GC
{
    __gshared Array!Root roots;
    __gshared Array!Range ranges;

    this()
    {
    }

    void Dtor()
    {
    }

    void enable()
    {
        gc_init_nothrow();
        gc_enable();
    }

    void disable()
    {
        gc_init_nothrow();
        gc_disable();
    }

    void collect() nothrow
    {
    }

    void collectNoStack() nothrow
    {
    }

    void minimize() nothrow
    {
    }

    uint getAttr(void* p) nothrow
    {
        return 0;
    }

    uint setAttr(void* p, uint mask) nothrow
    {
        return 0;
    }

    uint clrAttr(void* p, uint mask) nothrow
    {
        return 0;
    }

    void* malloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        gc_init_nothrow();
        return gc_malloc(size, bits, ti);
    }

    BlkInfo qalloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        gc_init_nothrow();
        return gc_qalloc(size, bits, ti);
    }

    void* calloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        gc_init_nothrow();
        return gc_calloc(size, bits, ti);
    }

    void* realloc(void* p, size_t size, uint bits, const TypeInfo ti) nothrow
    {
        gc_init_nothrow();
        return gc_realloc(p, size, bits, ti);
    }

    size_t extend(void* p, size_t minsize, size_t maxsize, const TypeInfo ti) nothrow
    {
        return 0;
    }

    size_t reserve(size_t size) nothrow
    {
        gc_init_nothrow();
        return reserve(size);
    }

    void free(void* p) nothrow @nogc
    {
        if (p) assert(false, "Invalid memory deallocation");
    }

    void* addrOf(void* p) nothrow @nogc
    {
        return null;
    }

    size_t sizeOf(void* p) nothrow @nogc
    {
        return 0;
    }

    BlkInfo query(void* p) nothrow
    {
        return BlkInfo.init;
    }

    core.memory.GC.Stats stats() nothrow
    {
        return typeof(return).init;
    }

    void addRoot(void* p) nothrow @nogc
    {
        gc_init_nothrow();
        gc_addRoot(p);
    }

    void removeRoot(void* p) nothrow @nogc
    {
    }

    @property RootIterator rootIter() return @nogc
    {
        return &rootsApply;
    }

    private int rootsApply(scope int delegate(ref Root) nothrow dg)
    {
        return 0;
    }

    void addRange(void* p, size_t sz, const TypeInfo ti = null) nothrow @nogc
    {
        gc_init_nothrow();
        gc_addRange(p, sz, ti);
    }

    void removeRange(void* p) nothrow @nogc
    {
    }

    @property RangeIterator rangeIter() return @nogc
    {
        return &rangesApply;
    }

    private int rangesApply(scope int delegate(ref Range) nothrow dg)
    {
        return 0;
    }

    void runFinalizers(in void[] segment) nothrow
    {
    }

    bool inFinalizer() nothrow
    {
        return false;
    }
}
