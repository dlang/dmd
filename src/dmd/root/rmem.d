/**
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/rmem.d, root/_rmem.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_rmem.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/rmem.d
 */

module dmd.root.rmem;

import core.exception : onOutOfMemoryError;
import core.stdc.string;

version (GC)
{
    import core.memory : GC;

    extern (C++) struct Mem
    {
        static char* xstrdup(const(char)* p) nothrow
        {
            return p[0 .. strlen(p) + 1].dup.ptr;
        }

        static void xfree(void* p) pure nothrow
        {
            return GC.free(p);
        }

        static void* xmalloc(size_t n) pure nothrow
        {
            return GC.malloc(n);
        }

        static void* xcalloc(size_t size, size_t n) pure nothrow
        {
            return GC.calloc(size * n);
        }

        static void* xrealloc(void* p, size_t size) pure nothrow
        {
            return GC.realloc(p, size);
        }

        static void error() pure nothrow
        {
            onOutOfMemoryError();
        }
    }

    extern (C) void* allocmemory(size_t m_size) nothrow
    {
        return GC.malloc(m_size);
    }

    extern (C++) const __gshared Mem mem;
}
else
{
    import core.memory;
    import core.stdc.stdlib;
    import core.stdc.stdio;

    extern (C++) struct Mem
    {
        static char* xstrdup(const(char)* s) nothrow
        {
            if (s)
            {
                auto p = .strdup(s);
                if (p)
                    return p;
                error();
            }
            return null;
        }

        static void xfree(void* p) pure nothrow
        {
            if (p)
                pureFree(p);
        }

        static void* xmalloc(size_t size) pure nothrow
        {
            if (!size)
                return null;

            auto p = pureMalloc(size);
            if (!p)
                error();
            return p;
        }

        static void* xcalloc(size_t size, size_t n) pure nothrow
        {
            if (!size || !n)
                return null;

            auto p = pureCalloc(size, n);
            if (!p)
                error();
            return p;
        }

        static void* xrealloc(void* p, size_t size) pure nothrow
        {
            if (!size)
            {
                if (p)
                    pureFree(p);
                return null;
            }

            if (!p)
            {
                p = pureMalloc(size);
                if (!p)
                    error();
                return p;
            }

            p = pureRealloc(p, size);
            if (!p)
                error();
            return p;
        }

        static void error() pure nothrow
        {
            onOutOfMemoryError();
        }
    }

    extern (C++) const __gshared Mem mem;

    enum CHUNK_SIZE = (256 * 4096 - 64);

    __gshared size_t heapleft = 0;
    __gshared void* heapp;

    extern (C) void* allocmemory(size_t m_size) nothrow
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
            auto p = malloc(m_size);
            if (p)
            {
                return p;
            }
            printf("Error: out of memory\n");
            exit(EXIT_FAILURE);
        }

        heapleft = CHUNK_SIZE;
        heapp = malloc(CHUNK_SIZE);
        if (!heapp)
        {
            printf("Error: out of memory\n");
            exit(EXIT_FAILURE);
        }
        goto L1;
    }

    version (DigitalMars)
    {
        enum OVERRIDE_MEMALLOC = true;
    }
    else version (LDC)
    {
        // Memory allocation functions gained weak linkage when the @weak attribute was introduced.
        import ldc.attributes;
        enum OVERRIDE_MEMALLOC = is(typeof(ldc.attributes.weak));
    }
    else
    {
        enum OVERRIDE_MEMALLOC = false;
    }

    static if (OVERRIDE_MEMALLOC)
    {
        extern (C) void* _d_allocmemory(size_t m_size) nothrow
        {
            return allocmemory(m_size);
        }

        extern (C) Object _d_newclass(const ClassInfo ci) nothrow
        {
            auto p = allocmemory(ci.initializer.length);
            p[0 .. ci.initializer.length] = cast(void[])ci.initializer[];
            return cast(Object)p;
        }

        version (LDC)
        {
            extern (C) Object _d_allocclass(const ClassInfo ci) nothrow
            {
                return cast(Object)allocmemory(ci.initializer.length);
            }
        }

        extern (C) void* _d_newitemT(TypeInfo ti) nothrow
        {
            auto p = allocmemory(ti.tsize);
            (cast(ubyte*)p)[0 .. ti.initializer.length] = 0;
            return p;
        }

        extern (C) void* _d_newitemiT(TypeInfo ti) nothrow
        {
            auto p = allocmemory(ti.tsize);
            p[0 .. ti.initializer.length] = ti.initializer[];
            return p;
        }

        // TypeInfo.initializer for compilers older than 2.070
        static if(!__traits(hasMember, TypeInfo, "initializer"))
        private const(void[]) initializer(T : TypeInfo)(const T t)
        nothrow pure @safe @nogc
        {
            return t.init;
        }
    }

// Copied from druntime. Remove these when GDC and LDC LTS is at a version
// corresponding to 2.074.0 or later.
private:
static if (!is(typeof(pureMalloc))):

    static import core.stdc.errno;

    /**
     * Pure variants of C's memory allocation functions `malloc`, `calloc`, and
     * `realloc` and deallocation function `free`.
     *
     * UNIX 98 requires that errno be set to ENOMEM upon failure.
     * Purity is achieved by saving and restoring the value of `errno`, thus
     * behaving as if it were never changed.
     *
     * See_Also:
     *     $(LINK2 https://dlang.org/spec/function.html#pure-functions, D's rules for purity),
     *     which allow for memory allocation under specific circumstances.
     */
    void* pureMalloc()(size_t size) @trusted pure @nogc nothrow
    {
        const errnosave = fakePureErrno;
        void* ret = fakePureMalloc(size);
        fakePureErrno = errnosave;
        return ret;
    }
    /// ditto
    void* pureCalloc()(size_t nmemb, size_t size) @trusted pure @nogc nothrow
    {
        const errnosave = fakePureErrno;
        void* ret = fakePureCalloc(nmemb, size);
        fakePureErrno = errnosave;
        return ret;
    }
    /// ditto
    void* pureRealloc()(void* ptr, size_t size) @system pure @nogc nothrow
    {
        const errnosave = fakePureErrno;
        void* ret = fakePureRealloc(ptr, size);
        fakePureErrno = errnosave;
        return ret;
    }
    /// ditto
    void pureFree()(void* ptr) @system pure @nogc nothrow
    {
        const errnosave = fakePureErrno;
        fakePureFree(ptr);
        fakePureErrno = errnosave;
    }

    extern (C) private pure @system @nogc nothrow
    {
        static import core.stdc.errno;

        pragma(mangle, "malloc") void* fakePureMalloc(size_t);
        pragma(mangle, "calloc") void* fakePureCalloc(size_t nmemb, size_t size);
        pragma(mangle, "realloc") void* fakePureRealloc(void* ptr, size_t size);

        pragma(mangle, "free") void fakePureFree(void* ptr);
    }

    static if (__traits(getOverloads, core.stdc.errno, "errno").length == 1
        && __traits(getLinkage, core.stdc.errno.errno) == "C")
    {
        extern(C) pragma(mangle, __traits(identifier, core.stdc.errno.errno))
        private ref int fakePureErrno() @nogc nothrow pure @system;
    }
    else
    {
        extern(C) private @nogc nothrow pure @system
        {
            pragma(mangle, "getErrno")
            private int fakePureGetErrno();

            pragma(mangle, "setErrno")
            private int fakePureSetErrno(int);
        }

        private @property int fakePureErrno()() @nogc nothrow pure @system
        {
            return fakePureGetErrno();
        }

        private @property void fakePureErrno()(int newValue) @nogc nothrow pure @system
        {
            cast(void) fakePureSetErrno(newValue);
        }
    }
}
/**
Makes a null-terminated copy of the given string on newly allocated memory.
The null-terminator won't be part of the returned string slice. It will be
at position `n` where `n` is the length of the input string.

Params:
    s = string to copy

Returns: A null-terminated copy of the input array.
*/
extern (D) char[] xarraydup(const(char)[] s) pure nothrow
{
    if (!s)
        return null;

    auto p = cast(char*)mem.xmalloc(s.length + 1);
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
    auto p = (cast(T*)mem.xmalloc(T.sizeof * dim))[0 .. dim];
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
