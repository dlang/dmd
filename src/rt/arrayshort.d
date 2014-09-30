/**
 * Contains SSE2 and MMX versions of certain operations for wchar, short,
 * and ushort ('u', 's' and 't' suffixes).
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
module rt.arrayshort;

// debug=PRINTF

private import core.cpuid;
import rt.util.array;

version (unittest)
{
    private import core.stdc.stdio : printf;
    /* This is so unit tests will test every CPU variant
     */
    int cpuid;
    const int CPUID_MAX = 4;
    @property bool mmx()      { return cpuid == 1 && core.cpuid.mmx; }
    @property bool sse()      { return cpuid == 2 && core.cpuid.sse; }
    @property bool sse2()     { return cpuid == 3 && core.cpuid.sse2; }
    @property bool amd3dnow() { return cpuid == 4 && core.cpuid.amd3dnow; }
}
else
{
    alias core.cpuid.mmx mmx;
    alias core.cpuid.sse sse;
    alias core.cpuid.sse2 sse2;
    alias core.cpuid.sse2 sse2;
}

//version = log;

alias short T;

extern (C) @trusted nothrow:

/* ======================================================================== */

/***********************
 * Computes:
 *      a[] = b[] + value
 */

T[] _arraySliceExpAddSliceAssign_u(T[] a, T value, T[] b)
{
    return _arraySliceExpAddSliceAssign_s(a, value, b);
}

T[] _arraySliceExpAddSliceAssign_t(T[] a, T value, T[] b)
{
    return _arraySliceExpAddSliceAssign_s(a, value, b);
}

T[] _arraySliceExpAddSliceAssign_s(T[] a, T value, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceExpAddSliceAssign_s()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 3343% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= (l << 16);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2u:
                    add ESI, 32;
                    movdqu XMM0, [EAX];
                    movdqu XMM1, [EAX+16];
                    add EAX, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM2;
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
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2a:
                    add ESI, 32;
                    movdqa XMM0, [EAX];
                    movdqa XMM1, [EAX+16];
                    add EAX, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM2;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
        }
        else
        // MMX version is 3343% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = cast(ushort) value;

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                movd MM2, l;
                pshufw MM2, MM2, 0;

                align 4;
            startmmx:
                add ESI, 16;
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                add EAX, 16;
                paddw MM0, MM2;
                paddw MM1, MM2;
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
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= (l << 16);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2u:
                    add RSI, 32;
                    movdqu XMM0, [RAX];
                    movdqu XMM1, [RAX+16];
                    add RAX, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM2;
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
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2a:
                    add RSI, 32;
                    movdqa XMM0, [RAX];
                    movdqa XMM1, [RAX+16];
                    add RAX, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM2;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2a;

                    mov aptr, RSI;
                    mov bptr, RAX;
                }
            }
        }
    }

    while (aptr < aend)
        *aptr++ = cast(T)(*bptr++ + value);

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceExpAddSliceAssign_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
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

T[] _arraySliceSliceAddSliceAssign_u(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceAddSliceAssign_s(a, c, b);
}

T[] _arraySliceSliceAddSliceAssign_t(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceAddSliceAssign_s(a, c, b);
}

T[] _arraySliceSliceAddSliceAssign_s(T[] a, T[] c, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);
    enforceTypedArraysConformable("vector operation", a, c);

    //printf("_arraySliceSliceAddSliceAssign_s()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 3777% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            if (((cast(uint) aptr | cast(uint) bptr | cast(uint) cptr) & 15) != 0)
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
                    movdqu XMM1, [EAX+16];
                    add EAX, 32;
                    movdqu XMM2, [ECX];
                    movdqu XMM3, [ECX+16];
                    add ECX, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM3;
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
                    movdqa XMM1, [EAX+16];
                    add EAX, 32;
                    movdqa XMM2, [ECX];
                    movdqa XMM3, [ECX+16];
                    add ECX, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM3;
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
        else
        // MMX version is 2068% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

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
                movq MM1, [EAX+8];
                add EAX, 16;
                movq MM2, [ECX];
                movq MM3, [ECX+8];
                add ECX, 16;
                paddw MM0, MM2;
                paddw MM1, MM3;
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
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            if (((cast(uint) aptr | cast(uint) bptr | cast(uint) cptr) & 15) != 0)
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
                    movdqu XMM1, [RAX+16];
                    add RAX, 32;
                    movdqu XMM2, [RCX];
                    movdqu XMM3, [RCX+16];
                    add RCX, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM3;
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
                    movdqa XMM1, [RAX+16];
                    add RAX, 32;
                    movdqa XMM2, [RCX];
                    movdqa XMM3, [RCX+16];
                    add RCX, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM3;
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
    }

    while (aptr < aend)
        *aptr++ = cast(T)(*bptr++ + *cptr++);

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceAddSliceAssign_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
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

T[] _arrayExpSliceAddass_u(T[] a, T value)
{
    return _arrayExpSliceAddass_s(a, value);
}

T[] _arrayExpSliceAddass_t(T[] a, T value)
{
    return _arrayExpSliceAddass_s(a, value);
}

T[] _arrayExpSliceAddass_s(T[] a, T value)
{
    //printf("_arrayExpSliceAddass_s(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 832% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= (l << 16);

            if (((cast(uint) aptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM1, [ESI+16];
                    add ESI, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM2;
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
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2a:
                    movdqa XMM0, [ESI];
                    movdqa XMM1, [ESI+16];
                    add ESI, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM2;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2a;

                    mov aptr, ESI;
                }
            }
        }
        else
        // MMX version is 826% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = cast(ushort) value;

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movd MM2, l;
                pshufw MM2, MM2, 0;

                align 4;
            startmmx:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                add ESI, 16;
                paddw MM0, MM2;
                paddw MM1, MM2;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
            }
        }
    }
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= (l << 16);

            if (((cast(uint) aptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2u:
                    movdqu XMM0, [RSI];
                    movdqu XMM1, [RSI+16];
                    add RSI, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM2;
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
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2a:
                    movdqa XMM0, [RSI];
                    movdqa XMM1, [RSI+16];
                    add RSI, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM2;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2a;

                    mov aptr, RSI;
                }
            }
        }
    }

    while (aptr < aend)
        *aptr++ += value;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arrayExpSliceAddass_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
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

T[] _arraySliceSliceAddass_u(T[] a, T[] b)
{
    return _arraySliceSliceAddass_s(a, b);
}

T[] _arraySliceSliceAddass_t(T[] a, T[] b)
{
    return _arraySliceSliceAddass_s(a, b);
}

T[] _arraySliceSliceAddass_s(T[] a, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceSliceAddass_s()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 2085% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov ECX, bptr;

                    align 4;
                startsse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM1, [ESI+16];
                    add ESI, 32;
                    movdqu XMM2, [ECX];
                    movdqu XMM3, [ECX+16];
                    add ECX, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM3;
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
                    movdqa XMM1, [ESI+16];
                    add ESI, 32;
                    movdqa XMM2, [ECX];
                    movdqa XMM3, [ECX+16];
                    add ECX, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM3;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2a;

                    mov aptr, ESI;
                    mov bptr, ECX;
                }
            }
        }
        else
        // MMX version is 1022% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov ECX, bptr;

                align 4;
            start:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                add ESI, 16;
                movq MM2, [ECX];
                movq MM3, [ECX+8];
                add ECX, 16;
                paddw MM0, MM2;
                paddw MM1, MM3;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb start;

                emms;
                mov aptr, ESI;
                mov bptr, ECX;
            }
        }
    }
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RCX, bptr;

                    align 4;
                startsse2u:
                    movdqu XMM0, [RSI];
                    movdqu XMM1, [RSI+16];
                    add RSI, 32;
                    movdqu XMM2, [RCX];
                    movdqu XMM3, [RCX+16];
                    add RCX, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM3;
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
                    movdqa XMM1, [RSI+16];
                    add RSI, 32;
                    movdqa XMM2, [RCX];
                    movdqa XMM3, [RCX+16];
                    add RCX, 32;
                    paddw XMM0, XMM2;
                    paddw XMM1, XMM3;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2a;

                    mov aptr, RSI;
                    mov bptr, RCX;
                }
            }
        }
    }

    while (aptr < aend)
        *aptr++ += *bptr++;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceAddass_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
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

T[] _arraySliceExpMinSliceAssign_u(T[] a, T value, T[] b)
{
    return _arraySliceExpMinSliceAssign_s(a, value, b);
}

T[] _arraySliceExpMinSliceAssign_t(T[] a, T value, T[] b)
{
    return _arraySliceExpMinSliceAssign_s(a, value, b);
}

T[] _arraySliceExpMinSliceAssign_s(T[] a, T value, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceExpMinSliceAssign_s()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 3695% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= (l << 16);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2u:
                    add ESI, 32;
                    movdqu XMM0, [EAX];
                    movdqu XMM1, [EAX+16];
                    add EAX, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM2;
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
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2a:
                    add ESI, 32;
                    movdqa XMM0, [EAX];
                    movdqa XMM1, [EAX+16];
                    add EAX, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM2;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
        }
        else
        // MMX version is 3049% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = cast(ushort) value;

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                movd MM2, l;
                pshufw MM2, MM2, 0;

                align 4;
            startmmx:
                add ESI, 16;
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                add EAX, 16;
                psubw MM0, MM2;
                psubw MM1, MM2;
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
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= (l << 16);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2u:
                    add RSI, 32;
                    movdqu XMM0, [RAX];
                    movdqu XMM1, [RAX+16];
                    add RAX, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM2;
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
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2a:
                    add RSI, 32;
                    movdqa XMM0, [RAX];
                    movdqa XMM1, [RAX+16];
                    add RAX, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM2;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2a;

                    mov aptr, RSI;
                    mov bptr, RAX;
                }
            }
        }
        else
        // MMX version is 3049% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = cast(ushort) value;

            asm
            {
                mov RSI, aptr;
                mov RDI, n;
                mov RAX, bptr;
                movd MM2, l;
                pshufw MM2, MM2, 0;

                align 4;
            startmmx:
                add RSI, 16;
                movq MM0, [RAX];
                movq MM1, [RAX+8];
                add RAX, 16;
                psubw MM0, MM2;
                psubw MM1, MM2;
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
        *aptr++ = cast(T)(*bptr++ - value);

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceExpMinSliceAssign_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
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

T[] _arrayExpSliceMinSliceAssign_u(T[] a, T[] b, T value)
{
    return _arrayExpSliceMinSliceAssign_s(a, b, value);
}

T[] _arrayExpSliceMinSliceAssign_t(T[] a, T[] b, T value)
{
    return _arrayExpSliceMinSliceAssign_s(a, b, value);
}

T[] _arrayExpSliceMinSliceAssign_s(T[] a, T[] b, T value)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arrayExpSliceMinSliceAssign_s()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 4995% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= (l << 16);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;

                    align 4;
                startaddsse2u:
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;
                    movd XMM3, l;
                    pshufd XMM3, XMM3, 0;
                    add ESI, 32;
                    movdqu XMM0, [EAX];
                    movdqu XMM1, [EAX+16];
                    add EAX, 32;
                    psubw XMM2, XMM0;
                    psubw XMM3, XMM1;
                    movdqu [ESI   -32], XMM2;
                    movdqu [ESI+16-32], XMM3;
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

                    align 4;
                startaddsse2a:
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;
                    movd XMM3, l;
                    pshufd XMM3, XMM3, 0;
                    add ESI, 32;
                    movdqa XMM0, [EAX];
                    movdqa XMM1, [EAX+16];
                    add EAX, 32;
                    psubw XMM2, XMM0;
                    psubw XMM3, XMM1;
                    movdqa [ESI   -32], XMM2;
                    movdqa [ESI+16-32], XMM3;
                    cmp ESI, EDI;
                    jb startaddsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
        }
        else
        // MMX version is 4562% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = cast(ushort) value;

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                movd MM4, l;
                pshufw MM4, MM4, 0;

                align 4;
            startmmx:
                add ESI, 16;
                movq MM2, [EAX];
                movq MM3, [EAX+8];
                movq MM0, MM4;
                movq MM1, MM4;
                add EAX, 16;
                psubw MM0, MM2;
                psubw MM1, MM3;
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
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= (l << 16);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;

                    align 4;
                startaddsse2u:
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;
                    movd XMM3, l;
                    pshufd XMM3, XMM3, 0;
                    add RSI, 32;
                    movdqu XMM0, [RAX];
                    movdqu XMM1, [RAX+16];
                    add RAX, 32;
                    psubw XMM2, XMM0;
                    psubw XMM3, XMM1;
                    movdqu [RSI   -32], XMM2;
                    movdqu [RSI+16-32], XMM3;
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

                    align 4;
                startaddsse2a:
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;
                    movd XMM3, l;
                    pshufd XMM3, XMM3, 0;
                    add RSI, 32;
                    movdqa XMM0, [RAX];
                    movdqa XMM1, [RAX+16];
                    add RAX, 32;
                    psubw XMM2, XMM0;
                    psubw XMM3, XMM1;
                    movdqa [RSI   -32], XMM2;
                    movdqa [RSI+16-32], XMM3;
                    cmp RSI, RDI;
                    jb startaddsse2a;

                    mov aptr, RSI;
                    mov bptr, RAX;
                }
            }
        }
    }

    while (aptr < aend)
        *aptr++ = cast(T)(value - *bptr++);

    return a;
}

unittest
{
    debug(PRINTF) printf("_arrayExpSliceMinSliceAssign_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
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

T[] _arraySliceSliceMinSliceAssign_u(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMinSliceAssign_s(a, c, b);
}

T[] _arraySliceSliceMinSliceAssign_t(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMinSliceAssign_s(a, c, b);
}

T[] _arraySliceSliceMinSliceAssign_s(T[] a, T[] c, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);
    enforceTypedArraysConformable("vector operation", a, c);

    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 4129% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            if (((cast(uint) aptr | cast(uint) bptr | cast(uint) cptr) & 15) != 0)
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
                    movdqu XMM1, [EAX+16];
                    add EAX, 32;
                    movdqu XMM2, [ECX];
                    movdqu XMM3, [ECX+16];
                    add ECX, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM3;
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
                    movdqa XMM1, [EAX+16];
                    add EAX, 32;
                    movdqa XMM2, [ECX];
                    movdqa XMM3, [ECX+16];
                    add ECX, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM3;
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
        else
        // MMX version is 2018% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

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
                movq MM1, [EAX+8];
                add EAX, 16;
                movq MM2, [ECX];
                movq MM3, [ECX+8];
                add ECX, 16;
                psubw MM0, MM2;
                psubw MM1, MM3;
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
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            if (((cast(uint) aptr | cast(uint) bptr | cast(uint) cptr) & 15) != 0)
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
                    movdqu XMM1, [RAX+16];
                    add RAX, 32;
                    movdqu XMM2, [RCX];
                    movdqu XMM3, [RCX+16];
                    add RCX, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM3;
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
                    movdqa XMM1, [RAX+16];
                    add RAX, 32;
                    movdqa XMM2, [RCX];
                    movdqa XMM3, [RCX+16];
                    add RCX, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM3;
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
    }

    while (aptr < aend)
        *aptr++ = cast(T)(*bptr++ - *cptr++);

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceMinSliceAssign_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
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

T[] _arrayExpSliceMinass_u(T[] a, T value)
{
    return _arrayExpSliceMinass_s(a, value);
}

T[] _arrayExpSliceMinass_t(T[] a, T value)
{
    return _arrayExpSliceMinass_s(a, value);
}

T[] _arrayExpSliceMinass_s(T[] a, T value)
{
    //printf("_arrayExpSliceMinass_s(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 835% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= (l << 16);

            if (((cast(uint) aptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM1, [ESI+16];
                    add ESI, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM2;
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
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2a:
                    movdqa XMM0, [ESI];
                    movdqa XMM1, [ESI+16];
                    add ESI, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM2;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startaddsse2a;

                    mov aptr, ESI;
                }
            }
        }
        else
        // MMX version is 835% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = cast(ushort) value;

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movd MM2, l;
                pshufw MM2, MM2, 0;

                align 4;
            startmmx:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                add ESI, 16;
                psubw MM0, MM2;
                psubw MM1, MM2;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
            }
        }
    }
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= (l << 16);

            if (((cast(uint) aptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2u:
                    movdqu XMM0, [RSI];
                    movdqu XMM1, [RSI+16];
                    add RSI, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM2;
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
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startaddsse2a:
                    movdqa XMM0, [RSI];
                    movdqa XMM1, [RSI+16];
                    add RSI, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM2;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startaddsse2a;

                    mov aptr, RSI;
                }
            }
        }
    }

    while (aptr < aend)
        *aptr++ -= value;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arrayExpSliceMinass_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
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

T[] _arraySliceSliceMinass_u(T[] a, T[] b)
{
    return _arraySliceSliceMinass_s(a, b);
}

T[] _arraySliceSliceMinass_t(T[] a, T[] b)
{
    return _arraySliceSliceMinass_s(a, b);
}

T[] _arraySliceSliceMinass_s(T[] a, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceSliceMinass_s()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 2121% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov ECX, bptr;

                    align 4;
                startsse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM1, [ESI+16];
                    add ESI, 32;
                    movdqu XMM2, [ECX];
                    movdqu XMM3, [ECX+16];
                    add ECX, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM3;
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
                    movdqa XMM1, [ESI+16];
                    add ESI, 32;
                    movdqa XMM2, [ECX];
                    movdqa XMM3, [ECX+16];
                    add ECX, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM3;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2a;

                    mov aptr, ESI;
                    mov bptr, ECX;
                }
            }
        }
        else
        // MMX version is 1116% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov ECX, bptr;

                align 4;
            start:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                add ESI, 16;
                movq MM2, [ECX];
                movq MM3, [ECX+8];
                add ECX, 16;
                psubw MM0, MM2;
                psubw MM1, MM3;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb start;

                emms;
                mov aptr, ESI;
                mov bptr, ECX;
            }
        }
    }
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RCX, bptr;

                    align 4;
                startsse2u:
                    movdqu XMM0, [RSI];
                    movdqu XMM1, [RSI+16];
                    add RSI, 32;
                    movdqu XMM2, [RCX];
                    movdqu XMM3, [RCX+16];
                    add RCX, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM3;
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
                    movdqa XMM1, [RSI+16];
                    add RSI, 32;
                    movdqa XMM2, [RCX];
                    movdqa XMM3, [RCX+16];
                    add RCX, 32;
                    psubw XMM0, XMM2;
                    psubw XMM1, XMM3;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2a;

                    mov aptr, RSI;
                    mov bptr, RCX;
                }
            }
        }
    }

    while (aptr < aend)
        *aptr++ -= *bptr++;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceMinass_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
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

T[] _arraySliceExpMulSliceAssign_u(T[] a, T value, T[] b)
{
    return _arraySliceExpMulSliceAssign_s(a, value, b);
}

T[] _arraySliceExpMulSliceAssign_t(T[] a, T value, T[] b)
{
    return _arraySliceExpMulSliceAssign_s(a, value, b);
}

T[] _arraySliceExpMulSliceAssign_s(T[] a, T value, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceExpMulSliceAssign_s()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 3733% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= l << 16;

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startsse2u:
                    add ESI, 32;
                    movdqu XMM0, [EAX];
                    movdqu XMM1, [EAX+16];
                    add EAX, 32;
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM2;
                    movdqu [ESI   -32], XMM0;
                    movdqu [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2u;

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
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startsse2a:
                    add ESI, 32;
                    movdqa XMM0, [EAX];
                    movdqa XMM1, [EAX+16];
                    add EAX, 32;
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM2;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
        }
        else
        // MMX version is 3733% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = cast(ushort) value;

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                movd MM2, l;
                pshufw MM2, MM2, 0;

                align 4;
            startmmx:
                add ESI, 16;
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                add EAX, 16;
                pmullw MM0, MM2;
                pmullw MM1, MM2;
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
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= l << 16;

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    mov RAX, bptr;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startsse2u:
                    add RSI, 32;
                    movdqu XMM0, [RAX];
                    movdqu XMM1, [RAX+16];
                    add RAX, 32;
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM2;
                    movdqu [RSI   -32], XMM0;
                    movdqu [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2u;

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
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startsse2a:
                    add RSI, 32;
                    movdqa XMM0, [RAX];
                    movdqa XMM1, [RAX+16];
                    add RAX, 32;
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM2;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2a;

                    mov aptr, RSI;
                    mov bptr, RAX;
                }
            }
        }
    }

    while (aptr < aend)
        *aptr++ = cast(T)(*bptr++ * value);

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceExpMulSliceAssign_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
            }

            c[] = a[] * 6;

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(a[i] * 6))
                {
                    printf("[%d]: %d != %d * 6\n", i, c[i], a[i]);
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

T[] _arraySliceSliceMulSliceAssign_u(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMulSliceAssign_s(a, c, b);
}

T[] _arraySliceSliceMulSliceAssign_t(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMulSliceAssign_s(a, c, b);
}

T[] _arraySliceSliceMulSliceAssign_s(T[] a, T[] c, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);
    enforceTypedArraysConformable("vector operation", a, c);

    //printf("_arraySliceSliceMulSliceAssign_s()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 2515% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            if (((cast(uint) aptr | cast(uint) bptr | cast(uint) cptr) & 15) != 0)
            {
                asm
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
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM3;
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
                asm
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
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM3;
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
        else
        // MMX version is 2515% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

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
                pmullw MM0, MM2;
                pmullw MM1, MM3;
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
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            if (((cast(uint) aptr | cast(uint) bptr | cast(uint) cptr) & 15) != 0)
            {
                asm
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
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM3;
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
                asm
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
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM3;
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
    }

    while (aptr < aend)
        *aptr++ = cast(T)(*bptr++ * *cptr++);

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceMulSliceAssign_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
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


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] *= value
 */

T[] _arrayExpSliceMulass_u(T[] a, T value)
{
    return _arrayExpSliceMulass_s(a, value);
}

T[] _arrayExpSliceMulass_t(T[] a, T value)
{
    return _arrayExpSliceMulass_s(a, value);
}

T[] _arrayExpSliceMulass_s(T[] a, T value)
{
    //printf("_arrayExpSliceMulass_s(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 2044% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= l << 16;

            if (((cast(uint) aptr) & 15) != 0)
            {
                asm
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startsse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM1, [ESI+16];
                    add ESI, 32;
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM2;
                    movdqu [ESI   -32], XMM0;
                    movdqu [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2u;

                    mov aptr, ESI;
                }
            }
            else
            {
                asm
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startsse2a:
                    movdqa XMM0, [ESI];
                    movdqa XMM1, [ESI+16];
                    add ESI, 32;
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM2;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2a;

                    mov aptr, ESI;
                }
            }
        }
        else
        // MMX version is 2056% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = cast(ushort) value;

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movd MM2, l;
                pshufw MM2, MM2, 0;

                align 4;
            startmmx:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                add ESI, 16;
                pmullw MM0, MM2;
                pmullw MM1, MM2;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
            }
        }
    }
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            uint l = cast(ushort) value;
            l |= l << 16;

            if (((cast(uint) aptr) & 15) != 0)
            {
                asm
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startsse2u:
                    movdqu XMM0, [RSI];
                    movdqu XMM1, [RSI+16];
                    add RSI, 32;
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM2;
                    movdqu [RSI   -32], XMM0;
                    movdqu [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2u;

                    mov aptr, RSI;
                }
            }
            else
            {
                asm
                {
                    mov RSI, aptr;
                    mov RDI, n;
                    movd XMM2, l;
                    pshufd XMM2, XMM2, 0;

                    align 4;
                startsse2a:
                    movdqa XMM0, [RSI];
                    movdqa XMM1, [RSI+16];
                    add RSI, 32;
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM2;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2a;

                    mov aptr, RSI;
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
    debug(PRINTF) printf("_arrayExpSliceMulass_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
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


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] *= b[]
 */

T[] _arraySliceSliceMulass_u(T[] a, T[] b)
{
    return _arraySliceSliceMulass_s(a, b);
}

T[] _arraySliceSliceMulass_t(T[] a, T[] b)
{
    return _arraySliceSliceMulass_s(a, b);
}

T[] _arraySliceSliceMulass_s(T[] a, T[] b)
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceSliceMulass_s()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 2519% faster
        if (sse2 && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm
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
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM3;
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
                asm
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
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM3;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2a;

                    mov aptr, ESI;
                    mov bptr, ECX;
               }
            }
        }
        else
        // MMX version is 1712% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

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
                pmullw MM0, MM2;
                pmullw MM1, MM3;
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
    else version (D_InlineAsm_X86_64)
    {
        // All known X86_64 have SSE2
        if (a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm
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
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM3;
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
                asm
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
                    pmullw XMM0, XMM2;
                    pmullw XMM1, XMM3;
                    movdqa [RSI   -32], XMM0;
                    movdqa [RSI+16-32], XMM1;
                    cmp RSI, RDI;
                    jb startsse2a;

                    mov aptr, RSI;
                    mov bptr, RCX;
               }
            }
        }
        else
        // MMX version is 1712% faster
        if (mmx && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

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
                pmullw MM0, MM2;
                pmullw MM1, MM3;
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
        *aptr++ *= *bptr++;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceMulass_s unittest\n");

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
            {   a[i] = cast(T)i;
                b[i] = cast(T)(i + 7);
                c[i] = cast(T)(i * 2);
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
