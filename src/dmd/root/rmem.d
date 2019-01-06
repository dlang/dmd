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

import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.string;

version = GC;

version (GC)
{
    import core.memory : GC;

    extern(C) void initGC(int argc, char **argv)
    {
        bool disable = true;
        version(Windows)
        {
            import core.sys.windows.windows;
            import core.stdc.wchar_;
            int args;
            auto argw = CommandLineToArgvW(GetCommandLineW(), &args);
            for (int i = 1; i < args; i++)
                if (argw[i][0..wcslen(argw[i])] == "-GC")
                    disable = false;
            LocalFree(argw);
        }
        else
        {
            for (int i = 0; i < argc; i++)
                if (argv[i][0..strlen(argv[i])] == "-GC")
                    disable = false;
        }
        if (disable)
            Mem.disableGC();
    }
}

extern (C++) struct Mem
{
    static char* xstrdup(const(char)* s) nothrow
    {
        if (!s)
            return null;

        version (GC)
            if (isGCEnabled)
                return s[0 .. strlen(s) + 1].dup.ptr;

        auto p = .strdup(s);
        if (!p)
            error();
        return p;
    }

    static void xfree(void* p) nothrow
    {
        if (!p)
            return;

        version (GC)
            if (isGCEnabled)
                return GC.free(p);

        .free(p);
    }

    static void* xmalloc(size_t size) nothrow
    {
        if (!size)
            return null;

        version (GC)
            if (isGCEnabled)
                return GC.malloc(size);

        auto p = .malloc(size);
        if (!p)
            error();
        return p;
    }

    static void* xcalloc(size_t size, size_t n) nothrow
    {
        const totalSize = size * n;
        if (!totalSize)
            return null;

        version (GC)
            if (isGCEnabled)
                return GC.calloc(totalSize);

        auto p = .calloc(size, n);
        if (!p)
            error();
        return p;
    }

    static void* xrealloc(void* p, size_t size) nothrow
    {
        version (GC)
            if (isGCEnabled)
                return GC.realloc(p, size);

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

    version (GC)
    {
        __gshared bool isGCEnabled = true;

        static void disableGC()
        {
            isGCEnabled = false;
        }

        static void addRange(const(void)* p, size_t size) nothrow
        {
            if (isGCEnabled)
                GC.addRange(p, size);
        }

        static void removeRange(const(void)* p) nothrow
        {
            if (isGCEnabled)
                GC.removeRange(p);
        }
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
    // Override the host druntime allocation functions in order to use the bump-
    // pointer allocation scheme (`allocmemory()` above) if the GC is disabled.
    // That scheme is faster and comes with less memory overhead than using a
    // disabled GC alone.

    extern (C) void* _d_allocmemory(size_t m_size) nothrow
    {
        version (GC)
            if (mem.isGCEnabled)
                return GC.malloc(m_size);

        return allocmemory(m_size);
    }

    version (GC)
    {
        private void* allocClass(const ClassInfo ci) nothrow
        {
            alias BlkAttr = GC.BlkAttr;

            assert(!(ci.m_flags & TypeInfo_Class.ClassFlags.isCOMclass));

            BlkAttr attr = BlkAttr.NONE;
            if (ci.m_flags & TypeInfo_Class.ClassFlags.hasDtor
                && !(ci.m_flags & TypeInfo_Class.ClassFlags.isCPPclass))
                attr |= BlkAttr.FINALIZE;
            if (ci.m_flags & TypeInfo_Class.ClassFlags.noPointers)
                attr |= BlkAttr.NO_SCAN;
            return GC.malloc(ci.initializer.length, attr, ci);
        }

        extern (C) void* _d_newitemU(const TypeInfo ti) nothrow;
    }

    extern (C) Object _d_newclass(const ClassInfo ci) nothrow
    {
        const initializer = ci.initializer;

        version (GC)
            auto p = mem.isGCEnabled ? allocClass(ci) : allocmemory(initializer.length);
        else
            auto p = allocmemory(initializer.length);

        memcpy(p, initializer.ptr, initializer.length);
        return cast(Object) p;
    }

    version (LDC)
    {
        extern (C) Object _d_allocclass(const ClassInfo ci) nothrow
        {
            version (GC)
                if (mem.isGCEnabled)
                    return cast(Object) allocClass(ci);

            return cast(Object) allocmemory(ci.initializer.length);
        }
    }

    extern (C) void* _d_newitemT(TypeInfo ti) nothrow
    {
        version (GC)
            auto p = mem.isGCEnabled ? _d_newitemU(ti) : allocmemory(ti.tsize);
        else
            auto p = allocmemory(ti.tsize);

        memset(p, 0, ti.tsize);
        return p;
    }

    extern (C) void* _d_newitemiT(TypeInfo ti) nothrow
    {
        version (GC)
            auto p = mem.isGCEnabled ? _d_newitemU(ti) : allocmemory(ti.tsize);
        else
            auto p = allocmemory(ti.tsize);

        const initializer = ti.initializer;
        memcpy(p, initializer.ptr, initializer.length);
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
