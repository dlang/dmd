/**
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/rmem.d, root/_rmem.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_rmem.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/rmem.d
 */

module dmd.root.rmem;

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

        static void xfree(void* p) nothrow
        {
            return GC.free(p);
        }

        static void* xmalloc(size_t n) nothrow
        {
            return GC.malloc(n);
        }

        static void* xcalloc(size_t size, size_t n) nothrow
        {
            return GC.calloc(size * n);
        }

        static void* xrealloc(void* p, size_t size) nothrow
        {
            return GC.realloc(p, size);
        }

        static void error() nothrow
        {
            import core.stdc.stdlib : exit, EXIT_FAILURE;
            import core.stdc.stdio : printf;

            printf("Error: out of memory\n");
            exit(EXIT_FAILURE);
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

        static void xfree(void* p) nothrow
        {
            if (p)
                .free(p);
        }

        static void* xmalloc(size_t size) nothrow
        {
            if (!size)
                return null;

            auto p = .malloc(size);
            if (!p)
                error();
            return p;
        }

        static void* xcalloc(size_t size, size_t n) nothrow
        {
            if (!size || !n)
                return null;

            auto p = .calloc(size, n);
            if (!p)
                error();
            return p;
        }

        static void* xrealloc(void* p, size_t size) nothrow
        {
            if (!size)
            {
                if (p)
                    .free(p);
                return null;
            }

            if (!p)
            {
                p = .malloc(size);
                if (!p)
                    error();
                return p;
            }

            p = .realloc(p, size);
            if (!p)
                error();
            return p;
        }

        static void error() nothrow
        {
            printf("Error: out of memory\n");
            exit(EXIT_FAILURE);
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
}
/**
Makes a null-terminated copy of the given string on newly allocated memory.
The null-terminator won't be part of the returned string slice. It will be
at position `n` where `n` is the length of the input string.

Params:
    s = string to copy

Returns: A null-terminated copy of the input array.
*/
extern (D) char[] xarraydup(const(char)[] s) nothrow
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
unittest
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
extern (D) T[] arraydup(T)(const scope T[] s) nothrow
{
    if (!s)
        return null;

    const dim = s.length;
    auto p = (cast(T*)mem.xmalloc(T.sizeof * dim))[0 .. dim];
    p[] = s;
    return p;
}

///
unittest
{
    auto s1 = [0, 1, 2];
    auto s2 = s1.arraydup;
    s2[0] = 4;
    assert(s1 == [0, 1, 2]);
    assert(s2 == [4, 1, 2]);
    string sEmpty;
    assert(sEmpty.arraydup is null);
}
