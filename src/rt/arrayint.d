/**
 * Contains MMX versions of certain operations for dchar, int, and uint ('w',
 * 'i' and 'k' suffixes).
 *
 * Copyright: Copyright Digital Mars 2008 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, based on code originally written by Burton Radons
 */

/*          Copyright Digital Mars 2008 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.arrayint;

// debug=PRINTF

private import core.cpuid;

version (unittest)
{
    private import core.stdc.stdio : printf;
    /* This is so unit tests will test every CPU variant
     */
    int cpuid;
    const int CPUID_MAX = 4;
    bool mmx()      { return cpuid == 1 && core.cpuid.mmx(); }
    bool sse()      { return cpuid == 2 && core.cpuid.sse(); }
    bool sse2()     { return cpuid == 3 && core.cpuid.sse2(); }
    bool amd3dnow() { return cpuid == 4 && core.cpuid.amd3dnow(); }
}
else
{
    alias core.cpuid.mmx mmx;
    alias core.cpuid.sse sse;
    alias core.cpuid.sse2 sse2;
    alias core.cpuid.amd3dnow amd3dnow;
}

//version = log;

bool disjoint(T)(T[] a, T[] b)
{
    return (a.ptr + a.length <= b.ptr || b.ptr + b.length <= a.ptr);
}

alias int T;

extern (C):

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
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpAddSliceAssign_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 380% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = value;

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
                    movd XMM2, l;
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
        else
        // MMX version is 298% faster
        if (mmx() && a.length >= 4)
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
        else
        if (a.length >= 2)
        {
            auto n = aptr + (a.length & ~1);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                mov EDX, value;

                align 4;
            start386:
                add ESI, 8;
                mov EBX, [EAX];
                mov ECX, [EAX+4];
                add EAX, 8;
                add EBX, EDX;
                add ECX, EDX;
                mov [ESI  -8], EBX;
                mov [ESI+4-8], ECX;
                cmp ESI, EDI;
                jb start386;

                mov aptr, ESI;
                mov bptr, EAX;
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

T[] _arraySliceSliceAddSliceAssign_w(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceAddSliceAssign_i(a, c, b);
}

T[] _arraySliceSliceAddSliceAssign_k(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceAddSliceAssign_i(a, c, b);
}

T[] _arraySliceSliceAddSliceAssign_i(T[] a, T[] c, T[] b)
in
{
        assert(a.length == b.length && b.length == c.length);
        assert(disjoint(a, b));
        assert(disjoint(a, c));
        assert(disjoint(b, c));
}
body
{
    //printf("_arraySliceSliceAddSliceAssign_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1710% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

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
        else
        // MMX version is 995% faster
        if (mmx() && a.length >= 4)
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

normal:
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
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = value;

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
                    movd XMM2, l;
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
        else
        // MMX version is 81% faster
        if (mmx() && a.length >= 4)
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
        else
        if (a.length >= 2)
        {
            auto n = aptr + (a.length & ~1);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EDX, value;

                align 4;
            start386:
                mov EBX, [ESI];
                mov ECX, [ESI+4];
                add ESI, 8;
                add EBX, EDX;
                add ECX, EDX;
                mov [ESI  -8], EBX;
                mov [ESI+4-8], ECX;
                cmp ESI, EDI;
                jb start386;

                mov aptr, ESI;
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

T[] _arraySliceSliceAddass_w(T[] a, T[] b)
{
    return _arraySliceSliceAddass_i(a, b);
}

T[] _arraySliceSliceAddass_k(T[] a, T[] b)
{
    return _arraySliceSliceAddass_i(a, b);
}

T[] _arraySliceSliceAddass_i(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceAddass_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 695% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

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
        else
        // MMX version is 471% faster
        if (mmx() && a.length >= 4)
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

normal:
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

T[] _arraySliceExpMinSliceAssign_w(T[] a, T value, T[] b)
{
    return _arraySliceExpMinSliceAssign_i(a, value, b);
}

T[] _arraySliceExpMinSliceAssign_k(T[] a, T value, T[] b)
{
    return _arraySliceExpMinSliceAssign_i(a, value, b);
}

T[] _arraySliceExpMinSliceAssign_i(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpMinSliceAssign_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 400% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = value;

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
                    movd XMM2, l;
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
        else
        // MMX version is 315% faster
        if (mmx() && a.length >= 4)
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
        else
        if (a.length >= 2)
        {
            auto n = aptr + (a.length & ~1);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                mov EDX, value;

                align 4;
            start386:
                add ESI, 8;
                mov EBX, [EAX];
                mov ECX, [EAX+4];
                add EAX, 8;
                sub EBX, EDX;
                sub ECX, EDX;
                mov [ESI  -8], EBX;
                mov [ESI+4-8], ECX;
                cmp ESI, EDI;
                jb start386;

                mov aptr, ESI;
                mov bptr, EAX;
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

T[] _arrayExpSliceMinSliceAssign_w(T[] a, T[] b, T value)
{
    return _arrayExpSliceMinSliceAssign_i(a, b, value);
}

T[] _arrayExpSliceMinSliceAssign_k(T[] a, T[] b, T value)
{
    return _arrayExpSliceMinSliceAssign_i(a, b, value);
}

T[] _arrayExpSliceMinSliceAssign_i(T[] a, T[] b, T value)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arrayExpSliceMinSliceAssign_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1812% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = value;

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM4, l;
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
                    movd XMM4, l;
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
        else
        // MMX version is 1077% faster
        if (mmx() && a.length >= 4)
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

T[] _arraySliceSliceMinSliceAssign_w(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMinSliceAssign_i(a, c, b);
}

T[] _arraySliceSliceMinSliceAssign_k(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMinSliceAssign_i(a, c, b);
}

T[] _arraySliceSliceMinSliceAssign_i(T[] a, T[] c, T[] b)
in
{
        assert(a.length == b.length && b.length == c.length);
        assert(disjoint(a, b));
        assert(disjoint(a, c));
        assert(disjoint(b, c));
}
body
{
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1721% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

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
        else
        // MMX version is 1002% faster
        if (mmx() && a.length >= 4)
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
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = value;

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
                    movd XMM2, l;
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
        else
        // MMX version is 81% faster
        if (mmx() && a.length >= 4)
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
        else
        if (a.length >= 2)
        {
            auto n = aptr + (a.length & ~1);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EDX, value;

                align 4;
            start386:
                mov EBX, [ESI];
                mov ECX, [ESI+4];
                add ESI, 8;
                sub EBX, EDX;
                sub ECX, EDX;
                mov [ESI  -8], EBX;
                mov [ESI+4-8], ECX;
                cmp ESI, EDI;
                jb start386;

                mov aptr, ESI;
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

T[] _arraySliceSliceMinass_w(T[] a, T[] b)
{
    return _arraySliceSliceMinass_i(a, b);
}

T[] _arraySliceSliceMinass_k(T[] a, T[] b)
{
    return _arraySliceSliceMinass_i(a, b);
}

T[] _arraySliceSliceMinass_i(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceMinass_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 731% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

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
        else
        // MMX version is 441% faster
        if (mmx() && a.length >= 4)
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

T[] _arraySliceExpMulSliceAssign_w(T[] a, T value, T[] b)
{
    return _arraySliceExpMulSliceAssign_i(a, value, b);
}

T[] _arraySliceExpMulSliceAssign_k(T[] a, T value, T[] b)
{
    return _arraySliceExpMulSliceAssign_i(a, value, b);
}

T[] _arraySliceExpMulSliceAssign_i(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpMulSliceAssign_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

  version (none)        // multiplying a pair is not supported by MMX
  {
    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1380% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = value;

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
                    pmuludq XMM0, XMM2;
                    pmuludq XMM1, XMM2;
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
                    pmuludq XMM0, XMM2;
                    pmuludq XMM1, XMM2;
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
        {
        // MMX version is 1380% faster
        if (mmx() && a.length >= 4)
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
                pmuludq MM0, MM2;       // only multiplies low 32 bits
                pmuludq MM1, MM2;
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
                //printf("[%d]: %d ?= %d * 6\n", i, c[i], a[i]);
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

T[] _arraySliceSliceMulSliceAssign_w(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMulSliceAssign_i(a, c, b);
}

T[] _arraySliceSliceMulSliceAssign_k(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMulSliceAssign_i(a, c, b);
}

T[] _arraySliceSliceMulSliceAssign_i(T[] a, T[] c, T[] b)
in
{
        assert(a.length == b.length && b.length == c.length);
        assert(disjoint(a, b));
        assert(disjoint(a, c));
        assert(disjoint(b, c));
}
body
{
    //printf("_arraySliceSliceMulSliceAssign_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

  version (none)
  {
    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1407% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

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
                    pmuludq XMM0, XMM2;
                    pmuludq XMM1, XMM3;
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
                    pmuludq XMM0, XMM2;
                    pmuludq XMM1, XMM3;
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
        // MMX version is 1029% faster
        if (mmx() && a.length >= 4)
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
                pmuludq MM0, MM2;
                pmuludq MM1, MM3;
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

  version (none)
  {
    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 400% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            uint l = value;

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
                    pmuludq XMM0, XMM2;
                    pmuludq XMM1, XMM2;
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
                    pmuludq XMM0, XMM2;
                    pmuludq XMM1, XMM2;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2a;

                    mov aptr, ESI;
                }
            }
        }
        else
        // MMX version is 402% faster
        if (mmx() && a.length >= 4)
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
                pmuludq MM0, MM2;
                pmuludq MM1, MM2;
                movq [ESI  -16], MM0;
                movq [ESI+8-16], MM1;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
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

T[] _arraySliceSliceMulass_w(T[] a, T[] b)
{
    return _arraySliceSliceMulass_i(a, b);
}

T[] _arraySliceSliceMulass_k(T[] a, T[] b)
{
    return _arraySliceSliceMulass_i(a, b);
}

T[] _arraySliceSliceMulass_i(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceMulass_i()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

  version (none)
  {
    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 873% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

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
                    pmuludq XMM0, XMM2;
                    pmuludq XMM1, XMM3;
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
                    pmuludq XMM0, XMM2;
                    pmuludq XMM1, XMM3;
                    movdqa [ESI   -32], XMM0;
                    movdqa [ESI+16-32], XMM1;
                    cmp ESI, EDI;
                    jb startsse2a;

                    mov aptr, ESI;
                    mov bptr, ECX;
               }
            }
        }
/+ BUG: comment out this section until we figure out what is going
   wrong with the invalid pshufd instructions.

        else
        // MMX version is 573% faster
        if (mmx() && a.length >= 4)
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
                pxor MM4, MM4;
                pxor MM5, MM5;
                punpckldq MM4, MM0;
                punpckldq MM5, MM2;
                add ESI, 16;
                add ECX, 16;
                pmuludq MM4, MM5;
                pshufd MM4, MM4, 8;     // ?
                movq [ESI  -16], MM4;
                pxor MM4, MM4;
                pxor MM5, MM5;
                punpckldq MM4, MM1;
                punpckldq MM5, MM3;
                pmuludq MM4, MM5;
                pshufd MM4, MM4, 8;     // ?
                movq [ESI+8-16], MM4;
                cmp ESI, EDI;
                jb startmmx;

                emms;
                mov aptr, ESI;
                mov bptr, ECX;
            }
        }
+/
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
