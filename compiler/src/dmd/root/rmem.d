/**
 * Allocate memory using `malloc` or the GC depending on the configuration.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, https://www.digitalmars.com
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/root/rmem.d, root/_rmem.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_rmem.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/root/rmem.d
 */

module dmd.root.rmem;

import core.exception : onOutOfMemoryError;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import core.memory : GC;

nothrow:

extern (C++) struct Mem
{
    static char* xstrdup(const(char)* s) nothrow
    {
        if (isGCEnabled)
            return s ? s[0 .. strlen(s) + 1].dup.ptr : null;

        return s ? cast(char*)check(.strdup(s)) : null;
    }

    static void xfree(void* p) pure nothrow
    {
        if (isGCEnabled)
            return GC.free(p);

        pureFree(p);
    }

    static void* xmalloc(size_t size) pure nothrow
    {
        if (isGCEnabled)
            return size ? GC.malloc(size) : null;

        return size ? check(pureMalloc(size)) : null;
    }

    static void* xmalloc_noscan(size_t size) pure nothrow
    {
        if (isGCEnabled)
            return size ? GC.malloc(size, GC.BlkAttr.NO_SCAN) : null;

        return size ? check(pureMalloc(size)) : null;
    }

    static void* xcalloc(size_t size, size_t n) pure nothrow
    {
        if (isGCEnabled)
            return size * n ? GC.calloc(size * n) : null;

        return (size && n) ? check(pureCalloc(size, n)) : null;
    }

    static void* xcalloc_noscan(size_t size, size_t n) pure nothrow
    {
        if (isGCEnabled)
            return size * n ? GC.calloc(size * n, GC.BlkAttr.NO_SCAN) : null;

        return (size && n) ? check(pureCalloc(size, n)) : null;
    }

    static void* xrealloc(void* p, size_t size) pure nothrow
    {
        if (isGCEnabled)
            return GC.realloc(p, size);

        if (!size)
        {
            pureFree(p);
            return null;
        }

        return check(pureRealloc(p, size));
    }

    static void* xrealloc_noscan(void* p, size_t size) pure nothrow
    {
        if (isGCEnabled)
            return GC.realloc(p, size, GC.BlkAttr.NO_SCAN);

        if (!size)
        {
            pureFree(p);
            return null;
        }

        return check(pureRealloc(p, size));
    }

    static void* error() pure nothrow @nogc @safe
    {
        onOutOfMemoryError();
        assert(0);
    }

    /**
     * Check p for null. If it is, issue out of memory error
     * and exit program.
     * Params:
     *  p = pointer to check for null
     * Returns:
     *  p if not null
     */
    static void* check(void* p) pure nothrow @nogc @safe
    {
        return p ? p : error();
    }

    __gshared bool _isGCEnabled = true;

    // fake purity by making global variable immutable (_isGCEnabled only modified before startup)
    enum _pIsGCEnabled = cast(immutable bool*) &_isGCEnabled;

    static bool isGCEnabled() pure nothrow @nogc @safe
    {
        return *_pIsGCEnabled;
    }

    static void disableGC() nothrow @nogc
    {
        _isGCEnabled = false;
    }

    static void addRange(const(void)* p, size_t size) nothrow @nogc
    {
        if (isGCEnabled)
            GC.addRange(p, size);
    }

    static void removeRange(const(void)* p) nothrow @nogc
    {
        if (isGCEnabled)
            GC.removeRange(p);
    }
}

extern (C++) const __gshared Mem mem;

enum CHUNK_SIZE = (256 * 4096 - 64);

__gshared size_t heapleft = 0;
__gshared void* heapp;
__gshared size_t heapTotal = 0; // Total amount of memory allocated using malloc

extern (D) void* allocmemoryNoFree(size_t m_size) nothrow @nogc
{
    // 16 byte alignment is better (and sometimes needed) for doubles
    m_size = (m_size + 15) & ~15;

    // The layout of the code is selected so the most common case is straight through
    if (m_size <= heapleft)
    {
    L1:
        heapleft -= m_size;
        auto p = heapp;
        heapp = cast(void*)(cast(char*)heapp + m_size);
        return p;
    }

    if (m_size > CHUNK_SIZE)
    {
        heapTotal += m_size;
        return Mem.check(malloc(m_size));
    }

    heapleft = CHUNK_SIZE;
    heapp = Mem.check(malloc(CHUNK_SIZE));
    heapTotal += CHUNK_SIZE;
    goto L1;
}

extern (D) void* allocmemory(size_t m_size) nothrow
{
    if (mem.isGCEnabled)
        return GC.malloc(m_size);

    return allocmemoryNoFree(m_size);
}

extern (C) pure @nogc nothrow
{
    /**
     * Pure variants of C's memory allocation functions `malloc`, `calloc`, and
     * `realloc` and deallocation function `free`.
     *
     * UNIX 98 requires that errno be set to ENOMEM upon failure.
     * https://linux.die.net/man/3/malloc
     * However, this is irrelevant for DMD's purposes, and best practice
     * protocol for using errno is to treat it as an `out` parameter, and not
     * something with state that can be relied on across function calls.
     * So, we'll ignore it.
     *
     * See_Also:
     *     $(LINK2 https://dlang.org/spec/function.html#pure-functions, D's rules for purity),
     *     which allow for memory allocation under specific circumstances.
     */
    pragma(mangle, "malloc") void* pureMalloc(size_t size) @trusted;

    /// ditto
    pragma(mangle, "calloc") void* pureCalloc(size_t nmemb, size_t size) @trusted;

    /// ditto
    pragma(mangle, "realloc") void* pureRealloc(void* ptr, size_t size) @system;

    /// ditto
    pragma(mangle, "free") void pureFree(void* ptr) @system;

}

/**
Makes a null-terminated copy of the given string on newly allocated memory.
The null-terminator won't be part of the returned string slice. It will be
at position `n` where `n` is the length of the input string.

Params:
    s = string to copy

Returns: A null-terminated copy of the input array.
*/
extern (D) char[] xarraydup(scope const(char)[] s) pure nothrow
{
    if (!s)
        return null;

    auto p = cast(char*)mem.xmalloc_noscan(s.length + 1);
    char[] a = p[0 .. s.length];
    a[] = s[0 .. s.length];
    p[s.length] = 0;    // preserve 0 terminator semantics
    return a;
}

///
pure nothrow unittest
{
    auto s1 = "foo";
    auto s2 = s1.xarraydup;
    s2[0] = 'b';
    assert(s1 == "foo");
    assert(s2 == "boo");
    assert(*(s2.ptr + s2.length) == '\0');
    string sEmpty;
    assert(sEmpty.xarraydup is null);
}

/**
Makes a copy of the given array on newly allocated memory.

Params:
    s = array to copy

Returns: A copy of the input array.
*/
extern (D) T[] arraydup(T)(const scope T[] s) pure nothrow
{
    if (!s)
        return null;

    const dim = s.length;
    auto p = (cast(T*)mem.xmalloc_noscan(T.sizeof * dim))[0 .. dim];
    p[] = s;
    return p;
}

///
pure nothrow unittest
{
    auto s1 = [0, 1, 2];
    auto s2 = s1.arraydup;
    s2[0] = 4;
    assert(s1 == [0, 1, 2]);
    assert(s2 == [4, 1, 2]);
    string sEmpty;
    assert(sEmpty.arraydup is null);
}

static if(__VERSION__ >= 2_096):
// access to conservative GC not available before this version, so we cannot proxy it

/////////////////////////////////////
// BumpPointerGC is a GC that uses the bump-pointer for most allocations, i.e.
//  it never frees anything, but uses the conservative GC for arrays
//
// Retrictions:
//  realloc and extend don't work on memory allocated without BlkAttr.APPENDABLE
//
import core.gc.gcinterface : GCInterface = GC, Root, Range, RootIterator, RangeIterator;
import core.internal.gc.impl.conservative.gc;

private extern(C) pragma(crt_constructor) void register_bump_gc()
{
    import core.gc.registry;
    registerGCFactory("bump", &BumpPointerGC.initialize);
}

class BumpPointerGC : GCInterface
{
    GCInterface gc;
    ulong allocated;

    static GCInterface initialize()
    {
        __gshared ubyte[__traits(classInstanceSize, BumpPointerGC)] buf;

        auto init = typeid(BumpPointerGC).initializer();
        assert(init.length == buf.length);
        auto instance = cast(BumpPointerGC) memcpy(buf.ptr, init.ptr, init.length);
        instance.__ctor();
        return instance;
    }

    this()
    {
        // unfortunately, registry cannot be invoked twice, and
        // initialize for ConservativeGC is private
        __gshared ubyte[__traits(classInstanceSize, ConservativeGC)] buf;

        auto init = typeid(ConservativeGC).initializer();
        assert(init.length == __traits(classInstanceSize, ConservativeGC));
        auto instance = cast(ConservativeGC) memcpy(buf.ptr, init.ptr, init.length);
        instance.__ctor();

        gc = instance;
        gc.disable();
    }

    ~this()
    {
        destroy(gc);

        import core.gc.config;
        if (config.profile)
            printf("\tAllocated by BumpGC:  %llu MB\n", allocated >> 20);
    }

    void enable()
    {
        // never enable collection in the conservative GC, memory from the
        // bump-pointer-allocation is not scanned
    }
    void disable()
    {
        gc.disable();
    }

    void collect() nothrow
    {
        gc.collect();
    }

    static if(__VERSION__ < 2_109)
        void collectNoStack() nothrow
        {
            gc.collectNoStack();
        }

    void minimize() nothrow
    {
        gc.minimize();
    }
    uint getAttr(void* p) nothrow
    {
        return gc.getAttr(p);
    }
    uint setAttr(void* p, uint mask) nothrow
    {
        return gc.setAttr(p, mask);
    }
    uint clrAttr(void* p, uint mask) nothrow
    {
        return gc.clrAttr(p, mask);
    }

    void* malloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        if (bits & GC.BlkAttr.APPENDABLE)
            return gc.malloc(size, bits, ti);
        allocated += size;
        return allocmemoryNoFree(size);
    }

    GC.BlkInfo qalloc(size_t size, uint bits, scope const TypeInfo ti) nothrow
    {
        if (bits & GC.BlkAttr.APPENDABLE)
            return gc.qalloc(size, bits, ti);
        allocated += size;
        GC.BlkInfo bi;
        bi.base = allocmemoryNoFree(size);
        bi.size = size;
        return bi;
    }

    void* calloc(size_t size, uint bits, const TypeInfo ti) nothrow
    {
        if (bits & GC.BlkAttr.APPENDABLE)
            return gc.calloc(size, bits, ti);
        allocated += size;
        void* p = allocmemoryNoFree(size);
        memset(p, 0, size);
        return p;
    }

    void* realloc(void* p, size_t size, uint bits, const TypeInfo ti) nothrow
    {
        if (!p || gc.query(p).base)
            return gc.realloc(p, size, bits, ti);
        assert(false, "GC.realloc must not be called on non-GC memory");
    }

    size_t extend(void* p, size_t minsize, size_t maxsize, const TypeInfo ti) nothrow
    {
        if (gc.query(p).base)
            return gc.extend(p, minsize, maxsize, ti);
        assert(false, "GC.extend must not be called on non-GC memory");
    }

    size_t reserve(size_t size) nothrow
    {
        return gc.reserve(size);
    }

    void free(void* p) nothrow
    {
        gc.free(p);
    }

    void* addrOf(void* p) nothrow
    {
        return gc.addrOf(p);
    }
    size_t sizeOf(void* p) nothrow
    {
        return gc.sizeOf(p);
    }

    GC.BlkInfo query(void* p) nothrow
    {
        return gc.query(p);
    }

    GC.Stats stats() nothrow
    {
        return gc.stats();
    }
    GC.ProfileStats profileStats() nothrow
    {
        return gc.profileStats();
    }

    void addRoot(void* p) nothrow @nogc
    {
        gc.addRoot(p);
    }
    void removeRoot(void* p) nothrow @nogc
    {
        gc.removeRoot(p);
    }
    @property RootIterator rootIter() @nogc
    {
        return gc.rootIter();
    }

    void addRange(void* p, size_t sz, const TypeInfo ti) nothrow @nogc
    {
        gc.addRange(p, sz, ti);
    }
    void removeRange(void* p) nothrow @nogc
    {
        gc.removeRange(p);
    }

    @property RangeIterator rangeIter() @nogc
    {
        return gc.rangeIter();
    }

    static if (__VERSION__ >= 2087)
        void runFinalizers(scope const void[] segment) nothrow
        {
            gc.runFinalizers(segment);
        }
    else
        void runFinalizers(in void[] segment) nothrow
        {
            gc.runFinalizers(segment);
        }

    bool inFinalizer() nothrow
    {
        return gc.inFinalizer();
    }
    ulong allocatedInCurrentThread() nothrow
    {
        return gc.allocatedInCurrentThread();
    }

    static if(__VERSION__ >= 2_111)
    {
        void[] getArrayUsed(void *ptr, bool atomic = false) nothrow
        {
            return gc.getArrayUsed(ptr, atomic);
        }
        bool expandArrayUsed(void[] slice, size_t newUsed, bool atomic = false) nothrow @safe
        {
            return gc.expandArrayUsed(slice, newUsed, atomic);
        }
        size_t reserveArrayCapacity(void[] slice, size_t request, bool atomic = false) nothrow @safe
        {
            return gc.reserveArrayCapacity(slice, request, atomic);
        }
        bool shrinkArrayUsed(void[] slice, size_t existingUsed, bool atomic = false) nothrow
        {
            return gc.shrinkArrayUsed(slice, existingUsed, atomic);
        }
    }
    static if(__VERSION__ >= 2_112)
    {
        import core.thread.threadbase : ThreadBase;
        void initThread(ThreadBase thread) nothrow @nogc
        {
            gc.initThread(thread);
        }
        void cleanupThread(ThreadBase thread) nothrow @nogc
        {
            gc.cleanupThread(thread);
        }
    }
}
