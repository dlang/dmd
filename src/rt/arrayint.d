/**
 * Contains SSE/MMX versions of certain operations for dchar, int, and uint ('w',
 * 'i' and 'k' suffixes).
 *
 * Copyright: Copyright Digital Mars 2008 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, based on code originally written by Burton Radons
 */

/*          Copyright Digital Mars 2008 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.arrayint;

// debug=PRINTF

private import core.cpuid;
import rt.util.array;

version (unittest)
{
    private import core.stdc.stdio : printf;
    /* This is so unit tests will test every CPU variant
     */
    uint cpuid;
    enum CPUID_MAX = 14;

nothrow:
    @property bool mmx()                { return cpuid == 1 && core.cpuid.mmx; }
    @property bool sse()                { return cpuid == 2 && core.cpuid.sse; }
    @property bool sse2()               { return cpuid == 3 && core.cpuid.sse2; }
    @property bool sse3()               { return cpuid == 4 && core.cpuid.sse3; }
    @property bool sse41()              { return cpuid == 5 && core.cpuid.sse41; }
    @property bool sse42()              { return cpuid == 6 && core.cpuid.sse42; }
    @property bool sse4a()              { return cpuid == 7 && core.cpuid.sse4a; }
    @property bool avx()                { return cpuid == 8 && core.cpuid.avx; }
    @property bool avx2()               { return cpuid == 9 && core.cpuid.avx2; }
    @property bool amd3dnow()           { return cpuid == 10 && core.cpuid.amd3dnow; }
    @property bool and3dnowExt()        { return cpuid == 11 && core.cpuid.amd3dnowExt; }
    @property bool amdMmx()             { return cpuid == 12 && core.cpuid.amdMmx; }
    @property bool has3dnowPrefetch()   { return cpuid == 13 && core.cpuid.has3dnowPrefetch; }
}
else
{
    version(X86_64) //guaranteed on x86_64
    {
        enum mmx = true;
        enum sse = true;
        enum sse2 = true;
    }
    else
    {
        alias core.cpuid.mmx mmx;
        alias core.cpuid.sse sse;
        alias core.cpuid.sse2 sse2;
    }
    alias core.cpuid.sse3 sse3;
    alias core.cpuid.sse41 sse41;
    alias core.cpuid.sse42 sse42;
    alias core.cpuid.sse4a sse4a;
    alias core.cpuid.avx avx;
    alias core.cpuid.avx2 avx2;
    alias core.cpuid.amd3dnow amd3dnow;
    alias core.cpuid.amd3dnowExt and3dnowExt;
    alias core.cpuid.amdMmx amdMmx;
    alias core.cpuid.has3dnowPrefetch has3dnowPrefetch;
}

//version = log;

alias int T;

extern (C) @trusted nothrow:

/* ======================================================================== */

/***********************
 * Computes:
 *      a[] = b[] + value
 */

T[] _arraySliceExpAddSliceAssign_w(T[] a, T value, T[] b)
{
    return _arraySliceExpAddSliceAssign_i(a, value, b);
}

T[] _arraySliceExpAddSliceAssign_k(T[] a, T value, T[] b)
{
    return _arraySliceExpAddSliceAssign_i(a, value, b);
}

T[] _arraySliceExpAddSliceAssign_i(T[] a, T value, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceExpAddSliceAssign_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 380% faster
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM2,value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2u:
                    add ESI, 32;
                    movdqu XMM0, [EAX];
                    movdqu XMM1, [EAX+16];
                    add EAX, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM2;
                    movdqu [ESI   -32], XMM0;
                    movdqu [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2u;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2a:
                    add ESI, 32;
                    movdqa XMM0, [EAX];
                    movdqa XMM1, [EAX+16];
                    add EAX, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM2;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
        }
        // MMX version is 298% faster
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            ulong l = cast(uint) value | ((cast(ulong)cast(uint) value) << 32);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                movq MM2, l;

                align 4;
              startmmx:
                add ESI, 16;
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                add EAX, 16;
                paddd MM0, MM2;
                paddd MM1, MM2;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2u:
                    add RSI, 32;
                    movdqu XMM0, [RAX];
                    movdqu XMM1, [RAX+16];
                    add RAX, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM2;
                    movdqu [RSI   -32], XMM0;
                    movdqu [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2u;

                    mov aptr, RSI;
                    mov bptr, RAX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    movd XMM2,value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2a:
                    add RSI, 32;
                    movdqa XMM0, [RAX];
                    movdqa XMM1, [RAX+16];
                    add RAX, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM2;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2a;

                    mov aptr, RSI;
                    mov bptr, RAX;
                }
            }
        }
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            ulong l = cast(uint) value | ((cast(ulong)cast(uint) value) << 32);

            asm
            {
                mov RSI, aptr;
                mov RDI, n;
                mov RAX, bptr;
                movq MM2, l;

                align 4;
              startmmx:
                add RSI, 16;
                movq MM0, [RAX];
                movq MM1, [RAX+8];
                add RAX, 16;
                paddd MM0, MM2;
                paddd MM1, MM2;
                movq [RSI  -16], MM0;
                movq [RSI+8-16], MM1;
                cmp RSI, RDI;
                jb startmmx;

                emms;
                mov aptr, RSI;
                mov bptr, RAX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ = *bptr++ + value;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceExpAddSliceAssign_i unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);

        for (int j = 0; j < 2; j++)
        {
            const int dim = 67;
            T[] a = new T[dim + j];     // aligned on 16 byte boundary
            a = a[j .. dim + j];        // misalign for second iteration
            T[] c = new T[dim + j];
            c = c[j .. dim + j];

            for (int i = 0; i < dim; i++)
            {
                a[i] = cast(T)(i-10);
                c[i] = cast(T)((i-10) * 2);
            }

            c[] = a[] + 6;

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(a[i] + 6))
                {
                    printf("[%d]: %d != %d + 6\n", i, c[i], a[i]);
                    assert(0);
                }
            }
        }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] = b[] + c[]
 */

T[] _arraySliceSliceAddSliceAssign_w(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceAddSliceAssign_i(a, c, b);
}

T[] _arraySliceSliceAddSliceAssign_k(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceAddSliceAssign_i(a, c, b);
}

T[] _arraySliceSliceAddSliceAssign_i(T[] a, T[] c, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);
    enforceTypedArraysConformable("vector operation", a, c);

    //printf("_arraySliceSliceAddSliceAssign_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1710% faster
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr | cast(size_t) cptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    mov ECX, cptr;

                    align 4;
                  startsse2u:
                    add ESI, 32;
                    movdqu XMM0, [EAX];
                    movdqu XMM2, [ECX];
                    movdqu XMM1, [EAX+16];
                    movdqu XMM3, [ECX+16];
                    add EAX, 32;
                    add ECX, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM3;
                    movdqu [ESI   -32], XMM0;
                    movdqu [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2u;

                    mov aptr, ESI;
                    mov bptr, EAX;
                    mov cptr, ECX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    mov ECX, cptr;

                    align 4;
                  startsse2a:
                    add ESI, 32;
                    movdqa XMM0, [EAX];
                    movdqa XMM2, [ECX];
                    movdqa XMM1, [EAX+16];
                    movdqa XMM3, [ECX+16];
                    add EAX, 32;
                    add ECX, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM3;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                    mov cptr, ECX;
                }
            }
        }
        // MMX version is 995% faster
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                mov ECX, cptr;

                align 4;
              startmmx:
                add ESI, 16;
                movq MM0, [EAX];
                movq MM2, [ECX];
                movq MM1, [EAX+8];
                movq MM3, [ECX+8];
                add EAX, 16;
                add ECX, 16;
                paddd MM0, MM2;
                paddd MM1, MM3;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
                mov cptr, ECX;
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr | cast(size_t) cptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    mov RCX, cptr;

                    align 4;
                  startsse2u:
                    add RSI, 32;
                    movdqu XMM0, [RAX];
                    movdqu XMM2, [RCX];
                    movdqu XMM1, [RAX+16];
                    movdqu XMM3, [RCX+16];
                    add RAX, 32;
                    add RCX, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM3;
                    movdqu [RSI   -32], XMM0;
                    movdqu [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2u;

                    mov aptr, RSI;
                    mov bptr, RAX;
                    mov cptr, RCX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    mov RCX, cptr;

                    align 4;
                  startsse2a:
                    add RSI, 32;
                    movdqa XMM0, [RAX];
                    movdqa XMM2, [RCX];
                    movdqa XMM1, [RAX+16];
                    movdqa XMM3, [RCX+16];
                    add RAX, 32;
                    add RCX, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM3;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2a;

                    mov aptr, RSI;
                    mov bptr, RAX;
                    mov cptr, RCX;
                }
            }
        }
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            asm
            {
                mov RSI, aptr;
                mov RDI, n;
                mov RAX, bptr;
                mov RCX, cptr;

                align 4;
              startmmx:
                add RSI, 16;
                movq MM0, [RAX];
                movq MM2, [RCX];
                movq MM1, [RAX+8];
                movq MM3, [RCX+8];
                add RAX, 16;
                add RCX, 16;
                paddd MM0, MM2;
                paddd MM1, MM3;
                movq [RSI  -16], MM0;
                movq [RSI+8-16], MM1;
                cmp RSI, RDI;
                jb startmmx;

                emms;
                mov aptr, RSI;
                mov bptr, RAX;
                mov cptr, RCX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ = *bptr++ + *cptr++;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceAddSliceAssign_i unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);

        for (int j = 0; j < 2; j++)
        {
            const int dim = 67;
            T[] a = new T[dim + j];     // aligned on 16 byte boundary
            a = a[j .. dim + j];        // misalign for second iteration
            T[] b = new T[dim + j];
            b = b[j .. dim + j];
            T[] c = new T[dim + j];
            c = c[j .. dim + j];

            for (int i = 0; i < dim; i++)
            {
                a[i] = cast(T)(i-10);
                b[i] = cast(T)(i-3);
                c[i] = cast(T)((i-10) * 2);
            }

            c[] = a[] + b[];

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(a[i] + b[i]))
                {
                    printf("[%d]: %d != %d + %d\n", i, c[i], a[i], b[i]);
                    assert(0);
                }
            }
        }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] += value
 */

T[] _arrayExpSliceAddass_w(T[] a, T value)
{
    return _arrayExpSliceAddass_i(a, value);
}

T[] _arrayExpSliceAddass_k(T[] a, T value)
{
    return _arrayExpSliceAddass_i(a, value);
}

T[] _arrayExpSliceAddass_i(T[] a, T value)
{
    //printf("_arrayExpSliceAddass_i(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 83% faster
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM1, [ESI+16];
                    add ESI, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM2;
                    movdqu [ESI   -32], XMM0;
                    movdqu [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2u;

                    mov aptr, ESI;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2a:
                    movdqa XMM0, [ESI];
                    movdqa XMM1, [ESI+16];
                    add ESI, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM2;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2a;

                    mov aptr, ESI;
                }
            }
        }
        // MMX version is 81% faster
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            ulong l = cast(uint) value | (cast(ulong)cast(uint) value << 32);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movq MM2, l;

                align 4;
              startmmx:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                add ESI, 16;
                paddd MM0, MM2;
                paddd MM1, MM2;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2u:
                    movdqu XMM0, [RSI];
                    movdqu XMM1, [RSI+16];
                    add RSI, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM2;
                    movdqu [RSI   -32], XMM0;
                    movdqu [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2u;

                    mov aptr, RSI;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2a:
                    movdqa XMM0, [RSI];
                    movdqa XMM1, [RSI+16];
                    add RSI, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM2;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2a;

                    mov aptr, RSI;
                }
            }
        }
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            ulong l = cast(uint) value | (cast(ulong)cast(uint) value << 32);

            asm
            {
                mov RSI, aptr;
                mov RDI, n;
                movq MM2, l;

                align 4;
              startmmx:
                movq MM0, [RSI];
                movq MM1, [RSI+8];
                add RSI, 16;
                paddd MM0, MM2;
                paddd MM1, MM2;
                movq [RSI  -16], MM0;
                movq [RSI+8-16], MM1;
                cmp RSI, RDI;
                jb startmmx;

                emms;
                mov aptr, RSI;
            }
        }
    }

    while (aptr < aend)
        *aptr++ += value;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arrayExpSliceAddass_i unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);

        for (int j = 0; j < 2; j++)
        {
            const int dim = 67;
            T[] a = new T[dim + j];     // aligned on 16 byte boundary
            a = a[j .. dim + j];        // misalign for second iteration
            T[] c = new T[dim + j];
            c = c[j .. dim + j];

            for (int i = 0; i < dim; i++)
            {
                a[i] = cast(T)(i-10);
                c[i] = cast(T)((i-10) * 2);
            }

            a[] = c[];
            a[] += 6;

            for (int i = 0; i < dim; i++)
            {
                if (a[i] != cast(T)(c[i] + 6))
                {
                    printf("[%d]: %d != %d + 6\n", i, a[i], c[i]);
                    assert(0);
                }
            }
        }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] += b[]
 */

T[] _arraySliceSliceAddass_w(T[] a, T[] b)
{
    return _arraySliceSliceAddass_i(a, b);
}

T[] _arraySliceSliceAddass_k(T[] a, T[] b)
{
    return _arraySliceSliceAddass_i(a, b);
}

T[] _arraySliceSliceAddass_i(T[] a, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceSliceAddass_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 695% faster
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov ECX, bptr;

                    align 4;
                  startsse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM2, [ECX];
                    movdqu XMM1, [ESI+16];
                    movdqu XMM3, [ECX+16];
                    add ESI, 32;
                    add ECX, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM3;
                    movdqu [ESI   -32], XMM0;
                    movdqu [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2u;

                    mov aptr, ESI;
                    mov bptr, ECX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov ECX, bptr;

                    align 4;
                  startsse2a:
                    movdqa XMM0, [ESI];
                    movdqa XMM2, [ECX];
                    movdqa XMM1, [ESI+16];
                    movdqa XMM3, [ECX+16];
                    add ESI, 32;
                    add ECX, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM3;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2a;

                    mov aptr, ESI;
                    mov bptr, ECX;
                }
            }
        }
        // MMX version is 471% faster
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov ECX, bptr;

                align 4;
              startmmx:
                movq MM0, [ESI];
                movq MM2, [ECX];
                movq MM1, [ESI+8];
                movq MM3, [ECX+8];
                add ESI, 16;
                add ECX, 16;
                paddd MM0, MM2;
                paddd MM1, MM3;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
                mov bptr, ECX;
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RCX, bptr;

                    align 4;
                  startsse2u:
                    movdqu XMM0, [RSI];
                    movdqu XMM2, [RCX];
                    movdqu XMM1, [RSI+16];
                    movdqu XMM3, [RCX+16];
                    add RSI, 32;
                    add RCX, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM3;
                    movdqu [RSI   -32], XMM0;
                    movdqu [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2u;

                    mov aptr, RSI;
                    mov bptr, RCX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RCX, bptr;

                    align 4;
                  startsse2a:
                    movdqa XMM0, [RSI];
                    movdqa XMM2, [RCX];
                    movdqa XMM1, [RSI+16];
                    movdqa XMM3, [RCX+16];
                    add RSI, 32;
                    add RCX, 32;
                    paddd XMM0, XMM2;
                    paddd XMM1, XMM3;
                    movdqa [RSI-32], XMM0;
                    movdqa [RSI-16], XMM1;

                    cmp RSI, RDI;
                    jb startsse2a;

                    mov aptr, RSI;
                    mov bptr, RCX;
                }
            }
        }
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            asm
            {
                mov RSI, aptr;
                mov RDI, n;
                mov RCX, bptr;

                align 4;
              startmmx:
                movq MM0, [RSI];
                movq MM2, [RCX];
                movq MM1, [RSI+8];
                movq MM3, [RCX+8];
                add RSI, 16;
                add RCX, 16;
                paddd MM0, MM2;
                paddd MM1, MM3;
                movq [RSI  -16], MM0;
                movq [RSI+8-16], MM1;
                cmp RSI, RDI;
                jb startmmx;

                emms;
                mov aptr, RSI;
                mov bptr, RCX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ += *bptr++;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceAddass_i unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);

        for (int j = 0; j < 2; j++)
        {
            const int dim = 67;
            T[] a = new T[dim + j];     // aligned on 16 byte boundary
            a = a[j .. dim + j];        // misalign for second iteration
            T[] b = new T[dim + j];
            b = b[j .. dim + j];
            T[] c = new T[dim + j];
            c = c[j .. dim + j];

            for (int i = 0; i < dim; i++)
            {
                a[i] = cast(T)(i-10);
                b[i] = cast(T)(i-3);
                c[i] = cast(T)((i-10) * 2);
            }

            b[] = c[];
            c[] += a[];

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(b[i] + a[i]))
                {
                    printf("[%d]: %d != %d + %d\n", i, c[i], b[i], a[i]);
                    assert(0);
                }
            }
        }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] = b[] - value
 */

T[] _arraySliceExpMinSliceAssign_w(T[] a, T value, T[] b)
{
    return _arraySliceExpMinSliceAssign_i(a, value, b);
}

T[] _arraySliceExpMinSliceAssign_k(T[] a, T value, T[] b)
{
    return _arraySliceExpMinSliceAssign_i(a, value, b);
}

T[] _arraySliceExpMinSliceAssign_i(T[] a, T value, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceExpMinSliceAssign_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 400% faster
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2u:
                    add ESI, 32;
                    movdqu XMM0, [EAX];
                    movdqu XMM1, [EAX+16];
                    add EAX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM2;
                    movdqu [ESI   -32], XMM0;
                    movdqu [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2u;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2a:
                    add ESI, 32;
                    movdqa XMM0, [EAX];
                    movdqa XMM1, [EAX+16];
                    add EAX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM2;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
        }
        // MMX version is 315% faster
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            ulong l = cast(uint) value | (cast(ulong)cast(uint) value << 32);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                movq MM2, l;

                align 4;
              startmmx:
                add ESI, 16;
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                add EAX, 16;
                psubd MM0, MM2;
                psubd MM1, MM2;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2u:
                    add RSI, 32;
                    movdqu XMM0, [EAX];
                    movdqu XMM1, [EAX+16];
                    add RAX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM2;
                    movdqu [RSI   -32], XMM0;
                    movdqu [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2u;

                    mov aptr, RSI;
                    mov bptr, RAX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2a:
                    add RSI, 32;
                    movdqa XMM0, [EAX];
                    movdqa XMM1, [EAX+16];
                    add RAX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM2;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2a;

                    mov aptr, RSI;
                    mov bptr, RAX;
                }
            }
        }
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            ulong l = cast(uint) value | (cast(ulong)cast(uint) value << 32);

            asm
            {
                mov RSI, aptr;
                mov RDI, n;
                mov RAX, bptr;
                movq MM2, l;

                align 4;
              startmmx:
                add RSI, 16;
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                add RAX, 16;
                psubd MM0, MM2;
                psubd MM1, MM2;
                movq [RSI  -16], MM0;
                movq [RSI+8-16], MM1;
                cmp RSI, RDI;
                jb startmmx;

                emms;
                mov aptr, RSI;
                mov bptr, RAX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ = *bptr++ - value;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceExpMinSliceAssign_i unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);

        for (int j = 0; j < 2; j++)
        {
            const int dim = 67;
            T[] a = new T[dim + j];     // aligned on 16 byte boundary
            a = a[j .. dim + j];        // misalign for second iteration
            T[] c = new T[dim + j];
            c = c[j .. dim + j];

            for (int i = 0; i < dim; i++)
            {
                a[i] = cast(T)(i-10);
                c[i] = cast(T)((i-10) * 2);
            }

            c[] = a[] - 6;

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(a[i] - 6))
                {
                    printf("[%d]: %d != %d - 6\n", i, c[i], a[i]);
                    assert(0);
                }
            }
        }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] = value - b[]
 */

T[] _arrayExpSliceMinSliceAssign_w(T[] a, T[] b, T value)
{
    return _arrayExpSliceMinSliceAssign_i(a, b, value);
}

T[] _arrayExpSliceMinSliceAssign_k(T[] a, T[] b, T value)
{
    return _arrayExpSliceMinSliceAssign_i(a, b, value);
}

T[] _arrayExpSliceMinSliceAssign_i(T[] a, T[] b, T value)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arrayExpSliceMinSliceAssign_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1812% faster
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM4, value;
                    pshufd XMM4, XMM4, 0;

                    align 4;
                  startaddsse2u:
                    add ESI, 32;
                    movdqu XMM2, [EAX];
                    movdqu XMM3, [EAX+16];
                    movdqa XMM0, XMM4;
                    movdqa XMM1, XMM4;
                    add EAX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM3;
                    movdqu [ESI   -32], XMM0;
                    movdqu [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2u;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM4, value;
                    pshufd XMM4, XMM4, 0;

                    align 4;
                  startaddsse2a:
                    add ESI, 32;
                    movdqa XMM2, [EAX];
                    movdqa XMM3, [EAX+16];
                    movdqa XMM0, XMM4;
                    movdqa XMM1, XMM4;
                    add EAX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM3;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
        }
        // MMX version is 1077% faster
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            ulong l = cast(uint) value | (cast(ulong)cast(uint) value << 32);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                movq MM4, l;

                align 4;
              startmmx:
                add ESI, 16;
                movq MM2, [EAX];
                movq MM3, [EAX+8];
                movq MM0, MM4;
                movq MM1, MM4;
                add EAX, 16;
                psubd MM0, MM2;
                psubd MM1, MM3;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    movd XMM4, value;
                    pshufd XMM4, XMM4, 0;

                    align 4;
                  startaddsse2u:
                    add RSI, 32;
                    movdqu XMM2, [RAX];
                    movdqu XMM3, [RAX+16];
                    movdqa XMM0, XMM4;
                    movdqa XMM1, XMM4;
                    add RAX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM3;
                    movdqu [RSI   -32], XMM0;
                    movdqu [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2u;

                    mov aptr, RSI;
                    mov bptr, RAX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    movd XMM4, value;
                    pshufd XMM4, XMM4, 0;

                    align 4;
                  startaddsse2a:
                    add RSI, 32;
                    movdqa XMM2, [EAX];
                    movdqa XMM3, [EAX+16];
                    movdqa XMM0, XMM4;
                    movdqa XMM1, XMM4;
                    add RAX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM3;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2a;

                    mov aptr, RSI;
                    mov bptr, RAX;
                }
            }
        }
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            ulong l = cast(uint) value | (cast(ulong)cast(uint) value << 32);

            asm
            {
                mov RSI, aptr;
                mov RDI, n;
                mov RAX, bptr;
                movq MM4, l;

                align 4;
              startmmx:
                add RSI, 16;
                movq MM2, [EAX];
                movq MM3, [EAX+8];
                movq MM0, MM4;
                movq MM1, MM4;
                add RAX, 16;
                psubd MM0, MM2;
                psubd MM1, MM3;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp RSI, RDI;
                jb startmmx;

                emms;
                mov aptr, RSI;
                mov bptr, RAX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ = value - *bptr++;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arrayExpSliceMinSliceAssign_i unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);

        for (int j = 0; j < 2; j++)
        {
            const int dim = 67;
            T[] a = new T[dim + j];     // aligned on 16 byte boundary
            a = a[j .. dim + j];        // misalign for second iteration
            T[] c = new T[dim + j];
            c = c[j .. dim + j];

            for (int i = 0; i < dim; i++)
            {
                a[i] = cast(T)(i-10);
                c[i] = cast(T)((i-10) * 2);
            }

            c[] = 6 - a[];

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(6 - a[i]))
                {
                    printf("[%d]: %d != 6 - %d\n", i, c[i], a[i]);
                    assert(0);
                }
            }
        }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] = b[] - c[]
 */

T[] _arraySliceSliceMinSliceAssign_w(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMinSliceAssign_i(a, c, b);
}

T[] _arraySliceSliceMinSliceAssign_k(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMinSliceAssign_i(a, c, b);
}

T[] _arraySliceSliceMinSliceAssign_i(T[] a, T[] c, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);
    enforceTypedArraysConformable("vector operation", a, c);

    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1721% faster
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr | cast(size_t) cptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    mov ECX, cptr;

                    align 4;
                  startsse2u:
                    add ESI, 32;
                    movdqu XMM0, [EAX];
                    movdqu XMM2, [ECX];
                    movdqu XMM1, [EAX+16];
                    movdqu XMM3, [ECX+16];
                    add EAX, 32;
                    add ECX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM3;
                    movdqu [ESI   -32], XMM0;
                    movdqu [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2u;

                    mov aptr, ESI;
                    mov bptr, EAX;
                    mov cptr, ECX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    mov ECX, cptr;

                    align 4;
                  startsse2a:
                    add ESI, 32;
                    movdqa XMM0, [EAX];
                    movdqa XMM2, [ECX];
                    movdqa XMM1, [EAX+16];
                    movdqa XMM3, [ECX+16];
                    add EAX, 32;
                    add ECX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM3;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                    mov cptr, ECX;
                }
            }
        }
        // MMX version is 1002% faster
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                mov ECX, cptr;

                align 4;
              startmmx:
                add ESI, 16;
                movq MM0, [EAX];
                movq MM2, [ECX];
                movq MM1, [EAX+8];
                movq MM3, [ECX+8];
                add EAX, 16;
                add ECX, 16;
                psubd MM0, MM2;
                psubd MM1, MM3;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
                mov cptr, ECX;
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr | cast(size_t) cptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    mov RCX, cptr;

                    align 4;
                  startsse2u:
                    add RSI, 32;
                    movdqu XMM0, [RAX];
                    movdqu XMM2, [RCX];
                    movdqu XMM1, [RAX+16];
                    movdqu XMM3, [RCX+16];
                    add RAX, 32;
                    add RCX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM3;
                    movdqu [RSI   -32], XMM0;
                    movdqu [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2u;

                    mov aptr, RSI;
                    mov bptr, RAX;
                    mov cptr, RCX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    mov RCX, cptr;

                    align 4;
                  startsse2a:
                    add RSI, 32;
                    movdqa XMM0, [RAX];
                    movdqa XMM2, [RCX];
                    movdqa XMM1, [RAX+16];
                    movdqa XMM3, [RCX+16];
                    add RAX, 32;
                    add RCX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM3;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2a;

                    mov aptr, RSI;
                    mov bptr, RAX;
                    mov cptr, RCX;
                }
            }
        }
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            asm
            {
                mov RSI, aptr;
                mov RDI, n;
                mov RAX, bptr;
                mov RCX, cptr;

                align 4;
              startmmx:
                add RSI, 16;
                movq MM0, [RAX];
                movq MM2, [RCX];
                movq MM1, [RAX+8];
                movq MM3, [RCX+8];
                add RAX, 16;
                add RCX, 16;
                psubd MM0, MM2;
                psubd MM1, MM3;
                movq [RSI  -16], MM0;
                movq [RSI+8-16], MM1;
                cmp RSI, RDI;
                jb startmmx;

                emms;
                mov aptr, RSI;
                mov bptr, RAX;
                mov cptr, RCX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ = *bptr++ - *cptr++;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceMinSliceAssign_i unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);

        for (int j = 0; j < 2; j++)
        {
            const int dim = 67;
            T[] a = new T[dim + j];     // aligned on 16 byte boundary
            a = a[j .. dim + j];        // misalign for second iteration
            T[] b = new T[dim + j];
            b = b[j .. dim + j];
            T[] c = new T[dim + j];
            c = c[j .. dim + j];

            for (int i = 0; i < dim; i++)
            {
                a[i] = cast(T)(i-10);
                b[i] = cast(T)(i-3);
                c[i] = cast(T)((i-10) * 2);
            }

            c[] = a[] - b[];

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(a[i] - b[i]))
                {
                    printf("[%d]: %d != %d - %d\n", i, c[i], a[i], b[i]);
                    assert(0);
                }
            }
        }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] -= value
 */

T[] _arrayExpSliceMinass_w(T[] a, T value)
{
    return _arrayExpSliceMinass_i(a, value);
}

T[] _arrayExpSliceMinass_k(T[] a, T value)
{
    return _arrayExpSliceMinass_i(a, value);
}

T[] _arrayExpSliceMinass_i(T[] a, T value)
{
    //printf("_arrayExpSliceMinass_i(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 81% faster
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM1, [ESI+16];
                    add ESI, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM2;
                    movdqu [ESI   -32], XMM0;
                    movdqu [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2u;

                    mov aptr, ESI;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2a:
                    movdqa XMM0, [ESI];
                    movdqa XMM1, [ESI+16];
                    add ESI, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM2;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2a;

                    mov aptr, ESI;
                }
            }
        }
        // MMX version is 81% faster
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            ulong l = cast(uint) value | (cast(ulong)cast(uint) value << 32);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movq MM2, l;

                align 4;
              startmmx:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                add ESI, 16;
                psubd MM0, MM2;
                psubd MM1, MM2;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2u:
                    movdqu XMM0, [RSI];
                    movdqu XMM1, [RSI+16];
                    add RSI, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM2;
                    movdqu [RSI   -32], XMM0;
                    movdqu [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2u;

                    mov aptr, RSI;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    movd XMM2, value;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                  startaddsse2a:
                    movdqa XMM0, [RSI];
                    movdqa XMM1, [RSI+16];
                    add RSI, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM2;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2a;

                    mov aptr, RSI;
                }
            }
        }
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            ulong l = cast(uint) value | (cast(ulong)cast(uint) value << 32);

            asm
            {
                mov RSI, aptr;
                mov RDI, n;
                movq MM2, l;

                align 4;
              startmmx:
                movq MM0, [RSI];
                movq MM1, [RSI+8];
                add RSI, 16;
                psubd MM0, MM2;
                psubd MM1, MM2;
                movq [RSI  -16], MM0;
                movq [RSI+8-16], MM1;
                cmp RSI, RDI;
                jb startmmx;

                emms;
                mov aptr, RSI;
            }
        }
    }

    while (aptr < aend)
        *aptr++ -= value;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arrayExpSliceMinass_i unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);

        for (int j = 0; j < 2; j++)
        {
            const int dim = 67;
            T[] a = new T[dim + j];     // aligned on 16 byte boundary
            a = a[j .. dim + j];        // misalign for second iteration
            T[] c = new T[dim + j];
            c = c[j .. dim + j];

            for (int i = 0; i < dim; i++)
            {
                a[i] = cast(T)(i-10);
                c[i] = cast(T)((i-10) * 2);
            }

            a[] = c[];
            a[] -= 6;

            for (int i = 0; i < dim; i++)
            {
                if (a[i] != cast(T)(c[i] - 6))
                {
                    printf("[%d]: %d != %d - 6\n", i, a[i], c[i]);
                    assert(0);
                }
            }
        }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] -= b[]
 */

T[] _arraySliceSliceMinass_w(T[] a, T[] b)
{
    return _arraySliceSliceMinass_i(a, b);
}

T[] _arraySliceSliceMinass_k(T[] a, T[] b)
{
    return _arraySliceSliceMinass_i(a, b);
}

T[] _arraySliceSliceMinass_i(T[] a, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceSliceMinass_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 731% faster
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov ECX, bptr;

                    align 4;
                  startsse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM2, [ECX];
                    movdqu XMM1, [ESI+16];
                    movdqu XMM3, [ECX+16];
                    add ESI, 32;
                    add ECX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM3;
                    movdqu [ESI   -32], XMM0;
                    movdqu [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2u;

                    mov aptr, ESI;
                    mov bptr, ECX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov ECX, bptr;

                    align 4;
                  startsse2a:
                    movdqa XMM0, [ESI];
                    movdqa XMM2, [ECX];
                    movdqa XMM1, [ESI+16];
                    movdqa XMM3, [ECX+16];
                    add ESI, 32;
                    add ECX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM3;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2a;

                    mov aptr, ESI;
                    mov bptr, ECX;
                }
            }
        }
        // MMX version is 441% faster
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov ECX, bptr;

                align 4;
              startmmx:
                movq MM0, [ESI];
                movq MM2, [ECX];
                movq MM1, [ESI+8];
                movq MM3, [ECX+8];
                add ESI, 16;
                add ECX, 16;
                psubd MM0, MM2;
                psubd MM1, MM3;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
                mov bptr, ECX;
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse2 && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            if (((cast(size_t) aptr | cast(size_t) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RCX, bptr;

                    align 4;
                  startsse2u:
                    movdqu XMM0, [RSI];
                    movdqu XMM2, [RCX];
                    movdqu XMM1, [RSI+16];
                    movdqu XMM3, [RCX+16];
                    add RSI, 32;
                    add RCX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM3;
                    movdqu [RSI   -32], XMM0;
                    movdqu [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2u;

                    mov aptr, RSI;
                    mov bptr, RCX;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RCX, bptr;

                    align 4;
                  startsse2a:
                    movdqa XMM0, [RSI];
                    movdqa XMM2, [RCX];
                    movdqa XMM1, [RSI+16];
                    movdqa XMM3, [RCX+16];
                    add RSI, 32;
                    add RCX, 32;
                    psubd XMM0, XMM2;
                    psubd XMM1, XMM3;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2a;

                    mov aptr, RSI;
                    mov bptr, RCX;
                }
            }
        }
        else if (mmx && a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);

            asm
            {
                mov RSI, aptr;
                mov RDI, n;
                mov RCX, bptr;

                align 4;
              startmmx:
                movq MM0, [RSI];
                movq MM2, [RCX];
                movq MM1, [RSI+8];
                movq MM3, [RCX+8];
                add RSI, 16;
                add RCX, 16;
                psubd MM0, MM2;
                psubd MM1, MM3;
                movq [RSI  -16], MM0;
                movq [RSI+8-16], MM1;
                cmp RSI, RDI;
                jb startmmx;

                emms;
                mov aptr, RSI;
                mov bptr, RCX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ -= *bptr++;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceMinass_i unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);

        for (int j = 0; j < 2; j++)
        {
            const int dim = 67;
            T[] a = new T[dim + j];     // aligned on 16 byte boundary
            a = a[j .. dim + j];        // misalign for second iteration
            T[] b = new T[dim + j];
            b = b[j .. dim + j];
            T[] c = new T[dim + j];
            c = c[j .. dim + j];

            for (int i = 0; i < dim; i++)
            {
                a[i] = cast(T)(i-10);
                b[i] = cast(T)(i-3);
                c[i] = cast(T)((i-10) * 2);
            }

            b[] = c[];
            c[] -= a[];

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(b[i] - a[i]))
                {
                    printf("[%d]: %d != %d - %d\n", i, c[i], b[i], a[i]);
                    assert(0);
                }
            }
        }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] = b[] * value
 */

T[] _arraySliceExpMulSliceAssign_w(T[] a, T value, T[] b)
{
    return _arraySliceExpMulSliceAssign_i(a, value, b);
}

T[] _arraySliceExpMulSliceAssign_k(T[] a, T value, T[] b)
{
    return _arraySliceExpMulSliceAssign_i(a, value, b);
}

T[] _arraySliceExpMulSliceAssign_i(T[] a, T value, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceExpMulSliceAssign_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        if (sse41)
        {
            auto aligned = ((cast(size_t) aptr | cast(size_t) bptr) & 15) == 0;

            if (a.length >= 8)
            {
                auto n = aptr + (a.length & ~7);

                if (!aligned)
                {
                    asm
                    {
                        mov ESI, aptr;
                        mov EDI, n;
                        mov EAX, bptr;
                        movd XMM2, value;
                        pshufd XMM2, XMM2, 0;

                        align 4;
                      startsse41u:
                        add ESI, 32;
                        movdqu XMM0, [EAX];
                        movdqu XMM1, [EAX+16];
                        add EAX, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM2;
                        movdqu [ESI   -32], XMM0;
                        movdqu [ESI+16-32], XMM1;
                        cmp ESI, EDI;
                        jb startsse41u;

                        mov aptr, ESI;
                        mov bptr, EAX;
                    }
                }
                else
                {
                    asm
                    {
                        mov ESI, aptr;
                        mov EDI, n;
                        mov EAX, bptr;
                        movd XMM1, value;
                        pshufd XMM2, XMM1, 0;

                        align 4;
                      startsse41a:
                        add ESI, 32;
                        movdqa XMM0, [EAX];
                        movdqa XMM1, [EAX+16];
                        add EAX, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM2;
                        movdqa [ESI   -32], XMM0;
                        movdqa [ESI+16-32], XMM1;
                        cmp ESI, EDI;
                        jb startsse41a;

                        mov aptr, ESI;
                        mov bptr, EAX;
                    }
                }
            }
            else if (a.length >= 4)
            {
                if (!aligned)
                {
                    asm
                    {
                        mov ESI, aptr;
                        mov EAX, bptr;
                        movd XMM1,value;
                        pshufd XMM1, XMM1, 0;

                        movdqu XMM0, [EAX];
                        pmulld XMM0, XMM1;
                        movdqu [ESI], XMM0;

                        add EAX, 16;
                        add ESI, 16;

                        mov aptr, ESI;
                        mov bptr, EAX;
                    }
                }
                else
                {
                    asm
                    {
                        mov ESI, aptr;
                        mov EAX, bptr;
                        movd XMM1,value;
                        pshufd XMM1, XMM1, 0;

                        movdqa XMM0, [EAX];
                        pmulld XMM0, XMM1;
                        movdqa [ESI], XMM0;

                        add EAX, 16;
                        add ESI, 16;

                        mov aptr, ESI;
                        mov bptr, EAX;
                    }
                }
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse41)
        {
            auto aligned = ((cast(size_t) aptr | cast(size_t) bptr) & 15) == 0;

            if (a.length >= 8)
            {
                auto n = aptr + (a.length & ~7);

                if (!aligned)
                {
                    asm
                    {
                        mov RSI, aptr;
                        mov RDI, n;
                        mov RAX, bptr;
                        movd XMM2, value;
                        pshufd XMM2, XMM2, 0;

                        align 4;
                      startsse41u:
                        add RSI, 32;
                        movdqu XMM0, [RAX];
                        movdqu XMM1, [RAX+16];
                        add RAX, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM2;
                        movdqu [RSI   -32], XMM0;
                        movdqu [RSI+16-32], XMM1;
                        cmp RSI, RDI;
                        jb startsse41u;

                        mov aptr, RSI;
                        mov bptr, RAX;
                    }
                }
                else
                {
                    asm
                    {
                        mov RSI, aptr;
                        mov RDI, n;
                        mov RAX, bptr;
                        movd XMM1, value;
                        pshufd XMM2, XMM1, 0;

                        align 4;
                      startsse41a:
                        add RSI, 32;
                        movdqa XMM0, [RAX];
                        movdqa XMM1, [RAX+16];
                        add RAX, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM2;
                        movdqa [RSI   -32], XMM0;
                        movdqa [RSI+16-32], XMM1;
                        cmp RSI, RDI;
                        jb startsse41a;

                        mov aptr, RSI;
                        mov bptr, RAX;
                    }
                }
            }
            else if (a.length >= 4)
            {
                if (!aligned)
                {//possibly slow, needs measuring
                    asm
                    {
                        mov RSI, aptr;
                        mov RAX, bptr;
                        movd XMM1, value;
                        pshufd XMM1, XMM1, 0;

                        movdqu XMM0, [RAX];
                        pmulld XMM0, XMM1;
                        movdqu [RSI], XMM0;

                        add RAX, 16;
                        add RSI, 16;

                        mov aptr, RSI;
                        mov bptr, RAX;
                    }
                }
                else
                {
                    asm
                    {
                        mov RSI, aptr;
                        mov RAX, bptr;
                        movd XMM1, value;
                        pshufd XMM1, XMM1, 0;

                        movdqa XMM0, [RAX];
                        pmulld XMM0, XMM1;
                        movdqa [RSI], XMM0;

                        add RAX, 16;
                        add RSI, 16;

                        mov aptr, RSI;
                        mov bptr, RAX;
                    }
                }
            }
        }
    }

    while (aptr < aend)
        *aptr++ = *bptr++ * value;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceExpMulSliceAssign_s unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);
        for (size_t dim = 7; dim < 68; dim += 60)
            for (int j = 0; j < 2; j++)
            {
                T[] b = new T[dim + j];     // aligned on 16 byte boundary
                b = b[j .. dim + j];        // misalign for second iteration
                T[] c = new T[dim + j];
                c = c[j .. dim + j];

                for (int i = 0; i < dim; i++)
                {
                    b[i] = cast(T)(i-3);
                    c[i] = cast(T)((i-10) * 2);
                }

                c[] = b[] * 6;
                for (int i = 0; i < dim; i++)
                {
                    //printf("[%d]: %d ?= %d * 6\n", i, c[i], b[i]);
                    if (c[i] != cast(T)(b[i] * 6))
                    {
                        printf("[%d]: %d != %d * 6\n", i, c[i], b[i]);
                        assert(0);
                    }
                }
            }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] = b[] * c[]
 */

T[] _arraySliceSliceMulSliceAssign_w(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMulSliceAssign_i(a, c, b);
}

T[] _arraySliceSliceMulSliceAssign_k(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMulSliceAssign_i(a, c, b);
}

T[] _arraySliceSliceMulSliceAssign_i(T[] a, T[] c, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);
    enforceTypedArraysConformable("vector operation", a, c);

    //printf("_arraySliceSliceMulSliceAssign_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        if (sse41)
        {
            auto aligned = ((cast(size_t) aptr | cast(size_t) bptr | cast(size_t) cptr) & 15) == 0;

            if (a.length >= 8)
            {
                auto n = aptr + (a.length & ~7);

                if (!aligned)
                {
                    asm
                    {
                        mov ESI, aptr;
                        mov EDI, n;
                        mov EAX, bptr;
                        mov ECX, cptr;

                        align 4;
                      startsse41u:
                        add ESI, 32;
                        movdqu XMM0, [EAX];
                        movdqu XMM2, [ECX];
                        movdqu XMM1, [EAX+16];
                        movdqu XMM3, [ECX+16];
                        add EAX, 32;
                        add ECX, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM3;
                        movdqu [ESI   -32], XMM0;
                        movdqu [ESI+16-32], XMM1;
                        cmp ESI, EDI;
                        jb startsse41u;

                        mov aptr, ESI;
                        mov bptr, EAX;
                        mov cptr, ECX;
                    }
                }
                else
                {
                    asm
                    {
                        mov ESI, aptr;
                        mov EDI, n;
                        mov EAX, bptr;
                        mov ECX, cptr;

                        align 4;
                      startsse41a:
                        add ESI, 32;
                        movdqa XMM0, [EAX];
                        movdqa XMM2, [ECX];
                        movdqa XMM1, [EAX+16];
                        movdqa XMM3, [ECX+16];
                        add EAX, 32;
                        add ECX, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM3;
                        movdqa [ESI   -32], XMM0;
                        movdqa [ESI+16-32], XMM1;
                        cmp ESI, EDI;
                        jb startsse41a;

                        mov aptr, ESI;
                        mov bptr, EAX;
                        mov cptr, ECX;
                    }
                }
            }
            else if (a.length >= 4)
            {
                if (!aligned)
                {//possibly not a good idea. Performance?
                    asm
                    {
                        mov ESI, aptr;
                        mov EAX, bptr;
                        mov ECX, cptr;

                        movdqu XMM0, [EAX];
                        movdqu XMM1, [ECX];
                        pmulld XMM0, XMM1;
                        movdqu [ESI], XMM0;

                        add ESI, 16;
                        add EAX, 16;
                        add ECX, 16;

                        mov aptr, ESI;
                        mov bptr, EAX;
                        mov cptr, ECX;
                    }
                }
                else
                {
                    asm
                    {
                        mov ESI, aptr;
                        mov EAX, bptr;
                        mov ECX, cptr;

                        movdqa XMM0, [EAX];
                        movdqa XMM1, [ECX];
                        pmulld XMM0, XMM1;
                        movdqu [ESI], XMM0;

                        add ESI, 16;
                        add EAX, 16;
                        add ECX, 16;

                        mov aptr, ESI;
                        mov bptr, EAX;
                        mov cptr, ECX;
                    }
                }
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse41)
        {
            auto aligned = ((cast(size_t) aptr | cast(size_t) bptr | cast(size_t) cptr) & 15) == 0;

            if (a.length >= 8)
            {
                auto n = aptr + (a.length & ~7);

                if (!aligned)
                {
                    asm
                    {
                        mov RSI, aptr;
                        mov RDI, n;
                        mov RAX, bptr;
                        mov RCX, cptr;

                        align 4;
                      startsse41u:
                        add RSI, 32;
                        movdqu XMM0, [RAX];
                        movdqu XMM2, [RCX];
                        movdqu XMM1, [RAX+16];
                        movdqu XMM3, [RCX+16];
                        add RAX, 32;
                        add RCX, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM3;
                        movdqu [RSI   -32], XMM0;
                        movdqu [RSI+16-32], XMM1;
                        cmp RSI, RDI;
                        jb startsse41u;

                        mov aptr, RSI;
                        mov bptr, RAX;
                        mov cptr, RCX;
                    }
                }
                else
                {
                    asm
                    {
                        mov RSI, aptr;
                        mov RDI, n;
                        mov RAX, bptr;
                        mov RCX, cptr;

                        align 4;
                      startsse41a:
                        add RSI, 32;
                        movdqa XMM0, [RAX];
                        movdqa XMM2, [RCX];
                        movdqa XMM1, [RAX+16];
                        movdqa XMM3, [RCX+16];
                        add RAX, 32;
                        add RCX, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM3;
                        movdqa [RSI   -32], XMM0;
                        movdqa [RSI+16-32], XMM1;
                        cmp RSI, RDI;
                        jb startsse41a;

                        mov aptr, RSI;
                        mov bptr, RAX;
                        mov cptr, RCX;
                    }
                }
            }
            else if (a.length >= 4)
            {
                if (!aligned)
                {//possibly not a good idea. Performance?
                    asm
                    {
                        mov RSI, aptr;
                        mov RAX, bptr;
                        mov RCX, cptr;

                        movdqu XMM0, [RAX];
                        movdqu XMM1, [RCX];
                        pmulld XMM0, XMM1;
                        movdqu [RSI], XMM0;

                        add RSI, 16;
                        add RAX, 16;
                        add RCX, 16;

                        mov aptr, RSI;
                        mov bptr, RAX;
                        mov cptr, RCX;
                    }
                }
                else
                {
                    asm
                    {
                        mov RSI, aptr;
                        mov RAX, bptr;
                        mov RCX, cptr;

                        movdqa XMM0, [RAX];
                        movdqa XMM1, [RCX];
                        pmulld XMM0, XMM1;
                        movdqu [RSI], XMM0;

                        add RSI, 16;
                        add RAX, 16;
                        add RCX, 16;

                        mov aptr, RSI;
                        mov bptr, RAX;
                        mov cptr, RCX;
                    }
                }
            }
        }
    }


    while (aptr < aend)
        *aptr++ = *bptr++ * *cptr++;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceMulSliceAssign_i unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);
        for (size_t dim = 7; dim < 68; dim += 60)
        {
            for (int j = 0; j < 2; j++)
            {
                T[] a = new T[dim + j];     // aligned on 16 byte boundary
                a = a[j .. dim + j];        // misalign for second iteration
                T[] b = new T[dim + j];
                b = b[j .. dim + j];
                T[] c = new T[dim + j];
                c = c[j .. dim + j];

                for (int i = 0; i < dim; i++)
                {
                    a[i] = cast(T)(i-10);
                    b[i] = cast(T)(i-3);
                    c[i] = cast(T)((i-10) * 2);
                }

                c[] = a[] * b[];

                for (int i = 0; i < dim; i++)
                {
                    if (c[i] != cast(T)(a[i] * b[i]))
                    {
                        printf("[%d]: %d != %d * %d\n", i, c[i], a[i], b[i]);
                        assert(0);
                    }
                }
            }
        }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] *= value
 */

T[] _arrayExpSliceMulass_w(T[] a, T value)
{
    return _arrayExpSliceMulass_i(a, value);
}

T[] _arrayExpSliceMulass_k(T[] a, T value)
{
    return _arrayExpSliceMulass_i(a, value);
}

T[] _arrayExpSliceMulass_i(T[] a, T value)
{
    //printf("_arrayExpSliceMulass_i(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        if (sse41)
        {
            auto aligned = ((cast(size_t) aptr) & 15) == 0;

            if (a.length >= 8)
            {
                auto n = aptr + (a.length & ~7);

                if (!aligned)
                {
                    asm
                    {
                        mov ESI, aptr;
                        mov EDI, n;
                        movd XMM2,value;
                        pshufd XMM2, XMM2, 0;

                        align 4;
                      startsse41u:
                        movdqu XMM0, [ESI];
                        movdqu XMM1, [ESI+16];
                        add ESI, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM2;
                        movdqu [ESI   -32], XMM0;
                        movdqu [ESI+16-32], XMM1;
                        cmp ESI, EDI;
                        jb startsse41u;

                        mov aptr, ESI;
                    }
                }
                else
                {
                    asm
                    {
                        mov ESI, aptr;
                        mov EDI, n;
                        movd XMM2,value;
                        pshufd XMM2, XMM2, 0;

                        align 4;
                      startsse41a:
                        movdqa XMM0, [ESI];
                        movdqa XMM1, [ESI+16];
                        add ESI, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM2;
                        movdqa [ESI   -32], XMM0;
                        movdqa [ESI+16-32], XMM1;
                        cmp ESI, EDI;
                        jb startsse41a;

                        mov aptr, ESI;
                    }
                }
            }
            else if (a.length >= 4)
            {
                if (!aligned)
                {
                    asm
                    {
                        mov ESI, aptr;
                        movd XMM2,value;
                        pshufd XMM2, XMM2, 0;

                        movdqu XMM0, [ESI];
                        pmulld XMM0, XMM2;
                        movdqu [ESI], XMM0;

                        add ESI, 16;
                        mov aptr, ESI;
                    }
                }
                else
                {
                    asm
                    {
                        mov ESI, aptr;
                        movd XMM2,value;
                        pshufd XMM2, XMM2, 0;

                        movdqa XMM0, [ESI];
                        pmulld XMM0, XMM2;
                        movdqa [ESI], XMM0;

                        add ESI, 16;
                        mov aptr, ESI;
                    }
                }
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse41)
        {
            auto aligned = ((cast(size_t) aptr) & 15) == 0;

            if (a.length >= 8)
            {
                auto n = aptr + (a.length & ~7);

                if (!aligned)
                {
                    asm
                    {
                        mov RSI, aptr;
                        mov RDI, n;
                        movd XMM2, value;
                        pshufd XMM2, XMM2, 0;

                        align 4;
                      startsse41u:
                        movdqu XMM0, [RSI];
                        movdqu XMM1, [RSI+16];
                        add RSI, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM2;
                        movdqu [RSI   -32], XMM0;
                        movdqu [RSI+16-32], XMM1;
                        cmp RSI, RDI;
                        jb startsse41u;

                        mov aptr, RSI;
                    }
                }
                else
                {
                    asm
                    {
                        mov RSI, aptr;
                        mov RDI, n;
                        movd XMM2, value;
                        pshufd XMM2, XMM2, 0;

                        align 4;
                      startsse41a:
                        movdqa XMM0, [RSI];
                        movdqa XMM1, [RSI+16];
                        add RSI, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM2;
                        movdqa [RSI   -32], XMM0;
                        movdqa [RSI+16-32], XMM1;
                        cmp RSI, RDI;
                        jb startsse41a;

                        mov aptr, RSI;
                    }
                }
            }
            else if (a.length >= 4)
            {
                if (!aligned)
                { //is the overhead worth it?
                    asm
                    {
                        mov RSI, aptr;
                        movd XMM2, value;
                        pshufd XMM2, XMM2, 0;

                        movdqu XMM0, [RSI];
                        pmulld XMM0, XMM2;
                        movdqu [RSI], XMM0;

                        add RSI, 16;
                        mov aptr, RSI;
                    }
                }
                else
                {
                    asm
                    {
                        mov RSI, aptr;
                        movd XMM2, value;
                        pshufd XMM2, XMM2, 0;

                        movdqa XMM0, [RSI];
                        pmulld XMM0, XMM2;
                        movdqa [RSI], XMM0;

                        add RSI, 16;
                        mov aptr, RSI;
                    }
                }
            }
        }
    }

    while (aptr < aend)
        *aptr++ *= value;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arrayExpSliceMulass_i unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);

        for (size_t dim = 7; dim < 68; dim += 60)
        {
            for (int j = 0; j < 2; j++)
            {
                T[] a = new T[dim + j];     // aligned on 16 byte boundary
                a = a[j .. dim + j];        // misalign for second iteration
                T[] b = new T[dim + j];
                b = b[j .. dim + j];

                for (int i = 0; i < dim; i++)
                {
                    a[i] = cast(T)(i-10);
                    b[i] = cast(T)(i-3);
                }

                b[] = a[];
                a[] *= 6;

                for (int i = 0; i < dim; i++)
                {
                    if (a[i] != cast(T)(b[i] * 6))
                    {
                        printf("[%d]: %d != %d * 6\n", i, a[i], b[i]);
                        assert(0);
                    }
                }
            }
        }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] *= b[]
 */

T[] _arraySliceSliceMulass_w(T[] a, T[] b)
{
    return _arraySliceSliceMulass_i(a, b);
}

T[] _arraySliceSliceMulass_k(T[] a, T[] b)
{
    return _arraySliceSliceMulass_i(a, b);
}

T[] _arraySliceSliceMulass_i(T[] a, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceSliceMulass_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        if (sse41)
        {
            auto aligned = ((cast(size_t) aptr) & 15) == 0;

            if (a.length >= 8)
            {
                auto n = aptr + (a.length & ~7);

                if (!aligned)
                {
                    asm
                    {
                        mov ESI, aptr;
                        mov EDI, n;
                        mov ECX, bptr;

                        align 4;
                      startsse41u:
                        movdqu XMM0, [ESI];
                        movdqu XMM2, [ECX];
                        movdqu XMM1, [ESI+16];
                        movdqu XMM3, [ECX+16];
                        add ESI, 32;
                        add ECX, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM3;
                        movdqu [ESI   -32], XMM0;
                        movdqu [ESI+16-32], XMM1;
                        cmp ESI, EDI;
                        jb startsse41u;

                        mov aptr, ESI;
                        mov bptr, ECX;
                    }
                }
                else
                {
                    asm
                    {
                        mov ESI, aptr;
                        mov EDI, n;
                        mov ECX, bptr;

                        align 4;
                      startsse41a:
                        movdqa XMM0, [ESI];
                        movdqa XMM2, [ECX];
                        movdqa XMM1, [ESI+16];
                        movdqa XMM3, [ECX+16];
                        add ESI, 32;
                        add ECX, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM3;
                        movdqa [ESI   -32], XMM0;
                        movdqa [ESI+16-32], XMM1;
                        cmp ESI, EDI;
                        jb startsse41a;

                        mov aptr, ESI;
                        mov bptr, ECX;
                    }
                }
            }
            else if (a.length >= 4)
            {
                if (!aligned)
                {//is the unaligned overhead worth it
                    asm
                    {
                        mov ESI, aptr;
                        mov ECX, bptr;

                        movdqu XMM0, [ESI];
                        movdqu XMM2, [ECX];

                        pmulld XMM0, XMM2;
                        movdqu [ESI], XMM0;

                        add ESI, 16;
                        add ECX, 16;

                        mov aptr, ESI;
                        mov bptr, ECX;
                    }
                }
                else
                {
                    asm
                    {
                        mov ESI, aptr;
                        mov ECX, bptr;

                        movdqa XMM0, [ESI];
                        movdqa XMM2, [ECX];

                        pmulld XMM0, XMM2;
                        movdqa [ESI], XMM0;

                        add ESI, 16;
                        add ECX, 16;

                        mov aptr, ESI;
                        mov bptr, ECX;
                    }
                }
            }
        }
    }
    version (D_InlineAsm_X86_64)
    {
        if (sse41)
        {
            auto aligned = ((cast(size_t) aptr) & 15) == 0;

            if (a.length >= 8)
            {
                auto n = aptr + (a.length & ~7);

                if (!aligned)
                {
                    asm
                    {
                        mov RSI, aptr;
                        mov RDI, n;
                        mov RCX, bptr;

                        align 4;
                      startsse41u:
                        movdqu XMM0, [RSI];
                        movdqu XMM2, [RCX];
                        movdqu XMM1, [RSI+16];
                        movdqu XMM3, [RCX+16];
                        add RSI, 32;
                        add RCX, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM3;
                        movdqu [RSI   -32], XMM0;
                        movdqu [RSI+16-32], XMM1;
                        cmp RSI, RDI;
                        jb startsse41u;

                        mov aptr, RSI;
                        mov bptr, RCX;
                    }
                }
                else
                {
                    asm
                    {
                        mov RSI, aptr;
                        mov RDI, n;
                        mov RCX, bptr;

                        align 4;
                      startsse41a:
                        movdqa XMM0, [RSI];
                        movdqa XMM2, [RCX];
                        movdqa XMM1, [RSI+16];
                        movdqa XMM3, [RCX+16];
                        add RSI, 32;
                        add RCX, 32;
                        pmulld XMM0, XMM2;
                        pmulld XMM1, XMM3;
                        movdqa [RSI   -32], XMM0;
                        movdqa [RSI+16-32], XMM1;
                        cmp RSI, RDI;
                        jb startsse41a;

                        mov aptr, RSI;
                        mov bptr, RCX;
                    }
                }
            }
            else if (a.length >= 4)
            {
                if (!aligned)
                {//is the unaligned overhead worth it
                    asm
                    {
                        mov RSI, aptr;
                        mov RCX, bptr;

                        movdqu XMM0, [RSI];
                        movdqu XMM2, [RCX];

                        pmulld XMM0, XMM2;
                        movdqu [RSI], XMM0;

                        add RSI, 16;
                        add RCX, 16;

                        mov aptr, RSI;
                        mov bptr, RCX;
                    }
                }
                else
                {
                    asm
                    {
                        mov RSI, aptr;
                        mov RCX, bptr;

                        movdqa XMM0, [RSI];
                        movdqa XMM2, [RCX];

                        pmulld XMM0, XMM2;
                        movdqa [RSI], XMM0;

                        add RSI, 16;
                        add RCX, 16;

                        mov aptr, RSI;
                        mov bptr, RCX;
                    }
                }
            }
        }
    }
    while (aptr < aend)
        *aptr++ *= *bptr++;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceMulass_i unittest\n");

    for (cpuid = 0; cpuid < CPUID_MAX; cpuid++)
    {
        version (log) printf("    cpuid %d\n", cpuid);

        for (size_t dim = 7; dim < 68; dim += 60)
        {
            for (int j = 0; j < 2; j++)
            {
                T[] a = new T[dim + j];     // aligned on 16 byte boundary
                a = a[j .. dim + j];        // misalign for second iteration
                T[] b = new T[dim + j];
                b = b[j .. dim + j];
                T[] c = new T[dim + j];
                c = c[j .. dim + j];

                for (int i = 0; i < dim; i++)
                {
                    a[i] = cast(T)(i-10);
                    b[i] = cast(T)(i-3);
                    c[i] = cast(T)((i-10) * 2);
                }

                b[] = a[];
                a[] *= c[];

                for (int i = 0; i < dim; i++)
                {
                    if (a[i] != cast(T)(b[i] * c[i]))
                    {
                        printf("[%d]: %d != %d * %d\n", i, a[i], b[i], c[i]);
                        assert(0);
                    }
                }
            }
        }
    }
}
