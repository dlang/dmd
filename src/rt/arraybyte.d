/**
 * Contains SSE2 and MMX versions of certain operations for char, byte, and
 * ubyte ('a', 'g' and 'h' suffixes).
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
module rt.arraybyte;

import core.cpuid;

// debug=PRINTF

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

alias byte T;

extern (C):

/* ======================================================================== */


/***********************
 * Computes:
 *      a[] = b[] + value
 */

T[] _arraySliceExpAddSliceAssign_a(T[] a, T value, T[] b)
{
    return _arraySliceExpAddSliceAssign_g(a, value, b);
}

T[] _arraySliceExpAddSliceAssign_h(T[] a, T value, T[] b)
{
    return _arraySliceExpAddSliceAssign_g(a, value, b);
}

T[] _arraySliceExpAddSliceAssign_g(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpAddSliceAssign_g()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1088% faster
        if (sse2() && a.length >= 64)
        {
            auto n = aptr + (a.length & ~63);

            uint l = cast(ubyte)value * 0x01010101;

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM4, l;
                    pshufd XMM4, XMM4, 0;

                    align 8;
                startaddsse2u:
                    add ESI, 64;
                    movdqu XMM0, [EAX];
                    movdqu XMM1, [EAX+16];
                    movdqu XMM2, [EAX+32];
                    movdqu XMM3, [EAX+48];
                    add EAX, 64;
                    paddb XMM0, XMM4;
                    paddb XMM1, XMM4;
                    paddb XMM2, XMM4;
                    paddb XMM3, XMM4;
                    movdqu [ESI   -64], XMM0;
                    movdqu [ESI+16-64], XMM1;
                    movdqu [ESI+32-64], XMM2;
                    movdqu [ESI+48-64], XMM3;
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

                    align 8;
                startaddsse2a:
                    add ESI, 64;
                    movdqa XMM0, [EAX];
                    movdqa XMM1, [EAX+16];
                    movdqa XMM2, [EAX+32];
                    movdqa XMM3, [EAX+48];
                    add EAX, 64;
                    paddb XMM0, XMM4;
                    paddb XMM1, XMM4;
                    paddb XMM2, XMM4;
                    paddb XMM3, XMM4;
                    movdqa [ESI   -64], XMM0;
                    movdqa [ESI+16-64], XMM1;
                    movdqa [ESI+32-64], XMM2;
                    movdqa [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startaddsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
        }
        else
        // MMX version is 1000% faster
        if (mmx() && a.length >= 32)
        {
            auto n = aptr + (a.length & ~31);

            uint l = cast(ubyte)value * 0x0101;

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                movd MM4, l;
                pshufw MM4, MM4, 0;

                align 4;
            startaddmmx:
                add ESI, 32;
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                add EAX, 32;
                paddb MM0, MM4;
                paddb MM1, MM4;
                paddb MM2, MM4;
                paddb MM3, MM4;
                movq [ESI   -32], MM0;
                movq [ESI+8 -32], MM1;
                movq [ESI+16-32], MM2;
                movq [ESI+24-32], MM3;
                cmp ESI, EDI;
                jb startaddmmx;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
        /* trying to be fair and treat normal 32-bit cpu the same way as we do
         * the SIMD units, with unrolled asm.  There's not enough registers,
         * really.
         */
        else
        if (a.length >= 4)
        {

            auto n = aptr + (a.length & ~3);
            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                mov CL, value;

                align 4;
            startadd386:
                add ESI, 4;
                mov DX, [EAX];
                mov BX, [EAX+2];
                add EAX, 4;
                add BL, CL;
                add BH, CL;
                add DL, CL;
                add DH, CL;
                mov [ESI   -4], DX;
                mov [ESI+2 -4], BX;
                cmp ESI, EDI;
                jb startadd386;

                mov aptr, ESI;
                mov bptr, EAX;
            }

        }
    }

    while (aptr < aend)
        *aptr++ = cast(T)(*bptr++ + value);

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceExpAddSliceAssign_g unittest\n");

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

T[] _arraySliceSliceAddSliceAssign_a(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceAddSliceAssign_g(a, c, b);
}

T[] _arraySliceSliceAddSliceAssign_h(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceAddSliceAssign_g(a, c, b);
}

T[] _arraySliceSliceAddSliceAssign_g(T[] a, T[] c, T[] b)
in
{
        assert(a.length == b.length && b.length == c.length);
        assert(disjoint(a, b));
        assert(disjoint(a, c));
        assert(disjoint(b, c));
}
body
{
    //printf("_arraySliceSliceAddSliceAssign_g()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 5739% faster
        if (sse2() && a.length >= 64)
        {
            auto n = aptr + (a.length & ~63);

            if (((cast(uint) aptr | cast(uint) bptr | cast(uint) cptr) & 15) != 0)
            {
                version (log) printf("\tsse2 unaligned\n");
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    mov ECX, cptr;

                    align 8;
                startaddlsse2u:
                    add ESI, 64;
                    movdqu XMM0, [EAX];
                    movdqu XMM1, [EAX+16];
                    movdqu XMM2, [EAX+32];
                    movdqu XMM3, [EAX+48];
                    add EAX, 64;
                    movdqu XMM4, [ECX];
                    movdqu XMM5, [ECX+16];
                    movdqu XMM6, [ECX+32];
                    movdqu XMM7, [ECX+48];
                    add ECX, 64;
                    paddb XMM0, XMM4;
                    paddb XMM1, XMM5;
                    paddb XMM2, XMM6;
                    paddb XMM3, XMM7;
                    movdqu [ESI   -64], XMM0;
                    movdqu [ESI+16-64], XMM1;
                    movdqu [ESI+32-64], XMM2;
                    movdqu [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startaddlsse2u;

                    mov aptr, ESI;
                    mov bptr, EAX;
                    mov cptr, ECX;
                }
            }
            else
            {
                version (log) printf("\tsse2 aligned\n");
                asm // aligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    mov ECX, cptr;

                    align 8;
                startaddlsse2a:
                    add ESI, 64;
                    movdqa XMM0, [EAX];
                    movdqa XMM1, [EAX+16];
                    movdqa XMM2, [EAX+32];
                    movdqa XMM3, [EAX+48];
                    add EAX, 64;
                    movdqa XMM4, [ECX];
                    movdqa XMM5, [ECX+16];
                    movdqa XMM6, [ECX+32];
                    movdqa XMM7, [ECX+48];
                    add ECX, 64;
                    paddb XMM0, XMM4;
                    paddb XMM1, XMM5;
                    paddb XMM2, XMM6;
                    paddb XMM3, XMM7;
                    movdqa [ESI   -64], XMM0;
                    movdqa [ESI+16-64], XMM1;
                    movdqa [ESI+32-64], XMM2;
                    movdqa [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startaddlsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                    mov cptr, ECX;
                }
            }
        }
        else
        // MMX version is 4428% faster
        if (mmx() && a.length >= 32)
        {
            version (log) printf("\tmmx\n");
            auto n = aptr + (a.length & ~31);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                mov ECX, cptr;

                align 4;
            startaddlmmx:
                add ESI, 32;
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                add EAX, 32;
                movq MM4, [ECX];
                movq MM5, [ECX+8];
                movq MM6, [ECX+16];
                movq MM7, [ECX+24];
                add ECX, 32;
                paddb MM0, MM4;
                paddb MM1, MM5;
                paddb MM2, MM6;
                paddb MM3, MM7;
                movq [ESI   -32], MM0;
                movq [ESI+8 -32], MM1;
                movq [ESI+16-32], MM2;
                movq [ESI+24-32], MM3;
                cmp ESI, EDI;
                jb startaddlmmx;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
                mov cptr, ECX;
            }
        }
    }

    version (log) if (aptr < aend) printf("\tbase\n");
    while (aptr < aend)
        *aptr++ = cast(T)(*bptr++ + *cptr++);

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceAddSliceAssign_g unittest\n");

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

T[] _arrayExpSliceAddass_a(T[] a, T value)
{
    return _arrayExpSliceAddass_g(a, value);
}

T[] _arrayExpSliceAddass_h(T[] a, T value)
{
    return _arrayExpSliceAddass_g(a, value);
}

T[] _arrayExpSliceAddass_g(T[] a, T value)
{
    //printf("_arrayExpSliceAddass_g(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1578% faster
        if (sse2() && a.length >= 64)
        {
            auto n = aptr + (a.length & ~63);

            uint l = cast(ubyte)value * 0x01010101;

            if (((cast(uint) aptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    movd XMM4, l;
                    pshufd XMM4, XMM4, 0;

                    align 8;
                startaddasssse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM1, [ESI+16];
                    movdqu XMM2, [ESI+32];
                    movdqu XMM3, [ESI+48];
                    add ESI, 64;
                    paddb XMM0, XMM4;
                    paddb XMM1, XMM4;
                    paddb XMM2, XMM4;
                    paddb XMM3, XMM4;
                    movdqu [ESI   -64], XMM0;
                    movdqu [ESI+16-64], XMM1;
                    movdqu [ESI+32-64], XMM2;
                    movdqu [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startaddasssse2u;

                    mov aptr, ESI;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    movd XMM4, l;
                    pshufd XMM4, XMM4, 0;

                    align 8;
                startaddasssse2a:
                    movdqa XMM0, [ESI];
                    movdqa XMM1, [ESI+16];
                    movdqa XMM2, [ESI+32];
                    movdqa XMM3, [ESI+48];
                    add ESI, 64;
                    paddb XMM0, XMM4;
                    paddb XMM1, XMM4;
                    paddb XMM2, XMM4;
                    paddb XMM3, XMM4;
                    movdqa [ESI   -64], XMM0;
                    movdqa [ESI+16-64], XMM1;
                    movdqa [ESI+32-64], XMM2;
                    movdqa [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startaddasssse2a;

                    mov aptr, ESI;
                }
            }
        }
        else
        // MMX version is 1721% faster
        if (mmx() && a.length >= 32)
        {

            auto n = aptr + (a.length & ~31);

            uint l = cast(ubyte)value * 0x0101;

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movd MM4, l;
                pshufw MM4, MM4, 0;

                align 8;
            startaddassmmx:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                movq MM2, [ESI+16];
                movq MM3, [ESI+24];
                add ESI, 32;
                paddb MM0, MM4;
                paddb MM1, MM4;
                paddb MM2, MM4;
                paddb MM3, MM4;
                movq [ESI   -32], MM0;
                movq [ESI+8 -32], MM1;
                movq [ESI+16-32], MM2;
                movq [ESI+24-32], MM3;
                cmp ESI, EDI;
                jb startaddassmmx;

                emms;
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
    debug(PRINTF) printf("_arrayExpSliceAddass_g unittest\n");

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
            c[] += 6;

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
 *      a[] += b[]
 */

T[] _arraySliceSliceAddass_a(T[] a, T[] b)
{
    return _arraySliceSliceAddass_g(a, b);
}

T[] _arraySliceSliceAddass_h(T[] a, T[] b)
{
    return _arraySliceSliceAddass_g(a, b);
}

T[] _arraySliceSliceAddass_g(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceAddass_g()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 4727% faster
        if (sse2() && a.length >= 64)
        {
            auto n = aptr + (a.length & ~63);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov ECX, bptr;

                    align 8;
                startaddasslsse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM1, [ESI+16];
                    movdqu XMM2, [ESI+32];
                    movdqu XMM3, [ESI+48];
                    add ESI, 64;
                    movdqu XMM4, [ECX];
                    movdqu XMM5, [ECX+16];
                    movdqu XMM6, [ECX+32];
                    movdqu XMM7, [ECX+48];
                    add ECX, 64;
                    paddb XMM0, XMM4;
                    paddb XMM1, XMM5;
                    paddb XMM2, XMM6;
                    paddb XMM3, XMM7;
                    movdqu [ESI   -64], XMM0;
                    movdqu [ESI+16-64], XMM1;
                    movdqu [ESI+32-64], XMM2;
                    movdqu [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startaddasslsse2u;

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

                    align 8;
                startaddasslsse2a:
                    movdqa XMM0, [ESI];
                    movdqa XMM1, [ESI+16];
                    movdqa XMM2, [ESI+32];
                    movdqa XMM3, [ESI+48];
                    add ESI, 64;
                    movdqa XMM4, [ECX];
                    movdqa XMM5, [ECX+16];
                    movdqa XMM6, [ECX+32];
                    movdqa XMM7, [ECX+48];
                    add ECX, 64;
                    paddb XMM0, XMM4;
                    paddb XMM1, XMM5;
                    paddb XMM2, XMM6;
                    paddb XMM3, XMM7;
                    movdqa [ESI   -64], XMM0;
                    movdqa [ESI+16-64], XMM1;
                    movdqa [ESI+32-64], XMM2;
                    movdqa [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startaddasslsse2a;

                    mov aptr, ESI;
                    mov bptr, ECX;
                }
            }
        }
        else
        // MMX version is 3059% faster
        if (mmx() && a.length >= 32)
        {

            auto n = aptr + (a.length & ~31);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov ECX, bptr;

                align 8;
            startaddasslmmx:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                movq MM2, [ESI+16];
                movq MM3, [ESI+24];
                add ESI, 32;
                movq MM4, [ECX];
                movq MM5, [ECX+8];
                movq MM6, [ECX+16];
                movq MM7, [ECX+24];
                add ECX, 32;
                paddb MM0, MM4;
                paddb MM1, MM5;
                paddb MM2, MM6;
                paddb MM3, MM7;
                movq [ESI   -32], MM0;
                movq [ESI+8 -32], MM1;
                movq [ESI+16-32], MM2;
                movq [ESI+24-32], MM3;
                cmp ESI, EDI;
                jb startaddasslmmx;

                emms;
                mov aptr, ESI;
                mov bptr, ECX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ += *bptr++;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceAddass_g unittest\n");

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
            c[] += b[];

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
 *      a[] = b[] - value
 */

T[] _arraySliceExpMinSliceAssign_a(T[] a, T value, T[] b)
{
    return _arraySliceExpMinSliceAssign_g(a, value, b);
}

T[] _arraySliceExpMinSliceAssign_h(T[] a, T value, T[] b)
{
    return _arraySliceExpMinSliceAssign_g(a, value, b);
}

T[] _arraySliceExpMinSliceAssign_g(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpMinSliceAssign_g()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1189% faster
        if (sse2() && a.length >= 64)
        {
            auto n = aptr + (a.length & ~63);

            uint l = cast(ubyte)value * 0x01010101;

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM4, l;
                    pshufd XMM4, XMM4, 0;

                    align 8;
                startsubsse2u:
                    add ESI, 64;
                    movdqu XMM0, [EAX];
                    movdqu XMM1, [EAX+16];
                    movdqu XMM2, [EAX+32];
                    movdqu XMM3, [EAX+48];
                    add EAX, 64;
                    psubb XMM0, XMM4;
                    psubb XMM1, XMM4;
                    psubb XMM2, XMM4;
                    psubb XMM3, XMM4;
                    movdqu [ESI   -64], XMM0;
                    movdqu [ESI+16-64], XMM1;
                    movdqu [ESI+32-64], XMM2;
                    movdqu [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startsubsse2u;

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

                    align 8;
                startsubsse2a:
                    add ESI, 64;
                    movdqa XMM0, [EAX];
                    movdqa XMM1, [EAX+16];
                    movdqa XMM2, [EAX+32];
                    movdqa XMM3, [EAX+48];
                    add EAX, 64;
                    psubb XMM0, XMM4;
                    psubb XMM1, XMM4;
                    psubb XMM2, XMM4;
                    psubb XMM3, XMM4;
                    movdqa [ESI   -64], XMM0;
                    movdqa [ESI+16-64], XMM1;
                    movdqa [ESI+32-64], XMM2;
                    movdqa [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startsubsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
        }
        else
        // MMX version is 1079% faster
        if (mmx() && a.length >= 32)
        {
            auto n = aptr + (a.length & ~31);

            uint l = cast(ubyte)value * 0x0101;

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                movd MM4, l;
                pshufw MM4, MM4, 0;

                align 4;
            startsubmmx:
                add ESI, 32;
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                add EAX, 32;
                psubb MM0, MM4;
                psubb MM1, MM4;
                psubb MM2, MM4;
                psubb MM3, MM4;
                movq [ESI   -32], MM0;
                movq [ESI+8 -32], MM1;
                movq [ESI+16-32], MM2;
                movq [ESI+24-32], MM3;
                cmp ESI, EDI;
                jb startsubmmx;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
        // trying to be fair and treat normal 32-bit cpu the same way as we do the SIMD units, with unrolled asm.  There's not enough registers, really.
        else
        if (a.length >= 4)
        {
            auto n = aptr + (a.length & ~3);
            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                mov CL, value;

                align 4;
            startsub386:
                add ESI, 4;
                mov DX, [EAX];
                mov BX, [EAX+2];
                add EAX, 4;
                sub BL, CL;
                sub BH, CL;
                sub DL, CL;
                sub DH, CL;
                mov [ESI   -4], DX;
                mov [ESI+2 -4], BX;
                cmp ESI, EDI;
                jb startsub386;

                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ = cast(T)(*bptr++ - value);

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceExpMinSliceAssign_g unittest\n");

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
            c[] = b[] - 6;

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(b[i] - 6))
                {
                    printf("[%d]: %d != %d - 6\n", i, c[i], b[i]);
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

T[] _arrayExpSliceMinSliceAssign_a(T[] a, T[] b, T value)
{
    return _arrayExpSliceMinSliceAssign_g(a, b, value);
}

T[] _arrayExpSliceMinSliceAssign_h(T[] a, T[] b, T value)
{
    return _arrayExpSliceMinSliceAssign_g(a, b, value);
}

T[] _arrayExpSliceMinSliceAssign_g(T[] a, T[] b, T value)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arrayExpSliceMinSliceAssign_g()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 8748% faster
        if (sse2() && a.length >= 64)
        {
            auto n = aptr + (a.length & ~63);

            uint l = cast(ubyte)value * 0x01010101;

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    movd XMM4, l;
                    pshufd XMM4, XMM4, 0;

                    align 8;
                startsubrsse2u:
                    add ESI, 64;
                    movdqa XMM5, XMM4;
                    movdqa XMM6, XMM4;
                    movdqu XMM0, [EAX];
                    movdqu XMM1, [EAX+16];
                    psubb XMM5, XMM0;
                    psubb XMM6, XMM1;
                    movdqu [ESI   -64], XMM5;
                    movdqu [ESI+16-64], XMM6;
                    movdqa XMM5, XMM4;
                    movdqa XMM6, XMM4;
                    movdqu XMM2, [EAX+32];
                    movdqu XMM3, [EAX+48];
                    add EAX, 64;
                    psubb XMM5, XMM2;
                    psubb XMM6, XMM3;
                    movdqu [ESI+32-64], XMM5;
                    movdqu [ESI+48-64], XMM6;
                    cmp ESI, EDI;
                    jb startsubrsse2u;

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

                    align 8;
                startsubrsse2a:
                    add ESI, 64;
                    movdqa XMM5, XMM4;
                    movdqa XMM6, XMM4;
                    movdqa XMM0, [EAX];
                    movdqa XMM1, [EAX+16];
                    psubb XMM5, XMM0;
                    psubb XMM6, XMM1;
                    movdqa [ESI   -64], XMM5;
                    movdqa [ESI+16-64], XMM6;
                    movdqa XMM5, XMM4;
                    movdqa XMM6, XMM4;
                    movdqa XMM2, [EAX+32];
                    movdqa XMM3, [EAX+48];
                    add EAX, 64;
                    psubb XMM5, XMM2;
                    psubb XMM6, XMM3;
                    movdqa [ESI+32-64], XMM5;
                    movdqa [ESI+48-64], XMM6;
                    cmp ESI, EDI;
                    jb startsubrsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                }
            }
        }
        else
        // MMX version is 7397% faster
        if (mmx() && a.length >= 32)
        {
            auto n = aptr + (a.length & ~31);

            uint l = cast(ubyte)value * 0x0101;

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                movd MM4, l;
                pshufw MM4, MM4, 0;

                align 4;
            startsubrmmx:
                add ESI, 32;
                movq MM5, MM4;
                movq MM6, MM4;
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                psubb MM5, MM0;
                psubb MM6, MM1;
                movq [ESI   -32], MM5;
                movq [ESI+8 -32], MM6;
                movq MM5, MM4;
                movq MM6, MM4;
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                add EAX, 32;
                psubb MM5, MM2;
                psubb MM6, MM3;
                movq [ESI+16-32], MM5;
                movq [ESI+24-32], MM6;
                cmp ESI, EDI;
                jb startsubrmmx;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
            }
        }

    }

    while (aptr < aend)
        *aptr++ = cast(T)(value - *bptr++);

    return a;
}

unittest
{
    debug(PRINTF) printf("_arrayExpSliceMinSliceAssign_g unittest\n");

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
            c[] = 6 - b[];

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(6 - b[i]))
                {
                    printf("[%d]: %d != 6 - %d\n", i, c[i], b[i]);
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

T[] _arraySliceSliceMinSliceAssign_a(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMinSliceAssign_g(a, c, b);
}

T[] _arraySliceSliceMinSliceAssign_h(T[] a, T[] c, T[] b)
{
    return _arraySliceSliceMinSliceAssign_g(a, c, b);
}

T[] _arraySliceSliceMinSliceAssign_g(T[] a, T[] c, T[] b)
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
        // SSE2 aligned version is 5756% faster
        if (sse2() && a.length >= 64)
        {
            auto n = aptr + (a.length & ~63);

            if (((cast(uint) aptr | cast(uint) bptr | cast(uint) cptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov EAX, bptr;
                    mov ECX, cptr;

                    align 8;
                startsublsse2u:
                    add ESI, 64;
                    movdqu XMM0, [EAX];
                    movdqu XMM1, [EAX+16];
                    movdqu XMM2, [EAX+32];
                    movdqu XMM3, [EAX+48];
                    add EAX, 64;
                    movdqu XMM4, [ECX];
                    movdqu XMM5, [ECX+16];
                    movdqu XMM6, [ECX+32];
                    movdqu XMM7, [ECX+48];
                    add ECX, 64;
                    psubb XMM0, XMM4;
                    psubb XMM1, XMM5;
                    psubb XMM2, XMM6;
                    psubb XMM3, XMM7;
                    movdqu [ESI   -64], XMM0;
                    movdqu [ESI+16-64], XMM1;
                    movdqu [ESI+32-64], XMM2;
                    movdqu [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startsublsse2u;

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

                    align 8;
                startsublsse2a:
                    add ESI, 64;
                    movdqa XMM0, [EAX];
                    movdqa XMM1, [EAX+16];
                    movdqa XMM2, [EAX+32];
                    movdqa XMM3, [EAX+48];
                    add EAX, 64;
                    movdqa XMM4, [ECX];
                    movdqa XMM5, [ECX+16];
                    movdqa XMM6, [ECX+32];
                    movdqa XMM7, [ECX+48];
                    add ECX, 64;
                    psubb XMM0, XMM4;
                    psubb XMM1, XMM5;
                    psubb XMM2, XMM6;
                    psubb XMM3, XMM7;
                    movdqa [ESI   -64], XMM0;
                    movdqa [ESI+16-64], XMM1;
                    movdqa [ESI+32-64], XMM2;
                    movdqa [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startsublsse2a;

                    mov aptr, ESI;
                    mov bptr, EAX;
                    mov cptr, ECX;
                }
            }
        }
        else
        // MMX version is 4428% faster
        if (mmx() && a.length >= 32)
        {
            auto n = aptr + (a.length & ~31);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                mov ECX, cptr;

                align 8;
            startsublmmx:
                add ESI, 32;
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                add EAX, 32;
                movq MM4, [ECX];
                movq MM5, [ECX+8];
                movq MM6, [ECX+16];
                movq MM7, [ECX+24];
                add ECX, 32;
                psubb MM0, MM4;
                psubb MM1, MM5;
                psubb MM2, MM6;
                psubb MM3, MM7;
                movq [ESI   -32], MM0;
                movq [ESI+8 -32], MM1;
                movq [ESI+16-32], MM2;
                movq [ESI+24-32], MM3;
                cmp ESI, EDI;
                jb startsublmmx;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
                mov cptr, ECX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ = cast(T)(*bptr++ - *cptr++);

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceSliceMinSliceAssign_g unittest\n");

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

T[] _arrayExpSliceMinass_a(T[] a, T value)
{
    return _arrayExpSliceMinass_g(a, value);
}

T[] _arrayExpSliceMinass_h(T[] a, T value)
{
    return _arrayExpSliceMinass_g(a, value);
}

T[] _arrayExpSliceMinass_g(T[] a, T value)
{
    //printf("_arrayExpSliceMinass_g(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1577% faster
        if (sse2() && a.length >= 64)
        {
            auto n = aptr + (a.length & ~63);

            uint l = cast(ubyte)value * 0x01010101;

            if (((cast(uint) aptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    movd XMM4, l;
                    pshufd XMM4, XMM4, 0;

                    align 8;
                startsubasssse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM1, [ESI+16];
                    movdqu XMM2, [ESI+32];
                    movdqu XMM3, [ESI+48];
                    add ESI, 64;
                    psubb XMM0, XMM4;
                    psubb XMM1, XMM4;
                    psubb XMM2, XMM4;
                    psubb XMM3, XMM4;
                    movdqu [ESI   -64], XMM0;
                    movdqu [ESI+16-64], XMM1;
                    movdqu [ESI+32-64], XMM2;
                    movdqu [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startsubasssse2u;

                    mov aptr, ESI;
                }
            }
            else
            {
                asm // aligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    movd XMM4, l;
                    pshufd XMM4, XMM4, 0;

                    align 8;
                startsubasssse2a:
                    movdqa XMM0, [ESI];
                    movdqa XMM1, [ESI+16];
                    movdqa XMM2, [ESI+32];
                    movdqa XMM3, [ESI+48];
                    add ESI, 64;
                    psubb XMM0, XMM4;
                    psubb XMM1, XMM4;
                    psubb XMM2, XMM4;
                    psubb XMM3, XMM4;
                    movdqa [ESI   -64], XMM0;
                    movdqa [ESI+16-64], XMM1;
                    movdqa [ESI+32-64], XMM2;
                    movdqa [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startsubasssse2a;

                    mov aptr, ESI;
                }
            }
        }
        else
        // MMX version is 1577% faster
        if (mmx() && a.length >= 32)
        {

            auto n = aptr + (a.length & ~31);

            uint l = cast(ubyte)value * 0x0101;

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movd MM4, l;
                pshufw MM4, MM4, 0;

                align 8;
            startsubassmmx:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                movq MM2, [ESI+16];
                movq MM3, [ESI+24];
                add ESI, 32;
                psubb MM0, MM4;
                psubb MM1, MM4;
                psubb MM2, MM4;
                psubb MM3, MM4;
                movq [ESI   -32], MM0;
                movq [ESI+8 -32], MM1;
                movq [ESI+16-32], MM2;
                movq [ESI+24-32], MM3;
                cmp ESI, EDI;
                jb startsubassmmx;

                emms;
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
    debug(PRINTF) printf("_arrayExpSliceMinass_g unittest\n");

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
            c[] -= 6;

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
 *      a[] -= b[]
 */

T[] _arraySliceSliceMinass_a(T[] a, T[] b)
{
    return _arraySliceSliceMinass_g(a, b);
}

T[] _arraySliceSliceMinass_h(T[] a, T[] b)
{
    return _arraySliceSliceMinass_g(a, b);
}

T[] _arraySliceSliceMinass_g(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceMinass_g()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 4800% faster
        if (sse2() && a.length >= 64)
        {
            auto n = aptr + (a.length & ~63);

            if (((cast(uint) aptr | cast(uint) bptr) & 15) != 0)
            {
                asm // unaligned case
                {
                    mov ESI, aptr;
                    mov EDI, n;
                    mov ECX, bptr;

                    align 8;
                startsubasslsse2u:
                    movdqu XMM0, [ESI];
                    movdqu XMM1, [ESI+16];
                    movdqu XMM2, [ESI+32];
                    movdqu XMM3, [ESI+48];
                    add ESI, 64;
                    movdqu XMM4, [ECX];
                    movdqu XMM5, [ECX+16];
                    movdqu XMM6, [ECX+32];
                    movdqu XMM7, [ECX+48];
                    add ECX, 64;
                    psubb XMM0, XMM4;
                    psubb XMM1, XMM5;
                    psubb XMM2, XMM6;
                    psubb XMM3, XMM7;
                    movdqu [ESI   -64], XMM0;
                    movdqu [ESI+16-64], XMM1;
                    movdqu [ESI+32-64], XMM2;
                    movdqu [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startsubasslsse2u;

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

                    align 8;
                startsubasslsse2a:
                    movdqa XMM0, [ESI];
                    movdqa XMM1, [ESI+16];
                    movdqa XMM2, [ESI+32];
                    movdqa XMM3, [ESI+48];
                    add ESI, 64;
                    movdqa XMM4, [ECX];
                    movdqa XMM5, [ECX+16];
                    movdqa XMM6, [ECX+32];
                    movdqa XMM7, [ECX+48];
                    add ECX, 64;
                    psubb XMM0, XMM4;
                    psubb XMM1, XMM5;
                    psubb XMM2, XMM6;
                    psubb XMM3, XMM7;
                    movdqa [ESI   -64], XMM0;
                    movdqa [ESI+16-64], XMM1;
                    movdqa [ESI+32-64], XMM2;
                    movdqa [ESI+48-64], XMM3;
                    cmp ESI, EDI;
                    jb startsubasslsse2a;

                    mov aptr, ESI;
                    mov bptr, ECX;
                }
            }
        }
        else
        // MMX version is 3107% faster
        if (mmx() && a.length >= 32)
        {

            auto n = aptr + (a.length & ~31);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov ECX, bptr;

                align 8;
            startsubasslmmx:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                movq MM2, [ESI+16];
                movq MM3, [ESI+24];
                add ESI, 32;
                movq MM4, [ECX];
                movq MM5, [ECX+8];
                movq MM6, [ECX+16];
                movq MM7, [ECX+24];
                add ECX, 32;
                psubb MM0, MM4;
                psubb MM1, MM5;
                psubb MM2, MM6;
                psubb MM3, MM7;
                movq [ESI   -32], MM0;
                movq [ESI+8 -32], MM1;
                movq [ESI+16-32], MM2;
                movq [ESI+24-32], MM3;
                cmp ESI, EDI;
                jb startsubasslmmx;

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
    debug(PRINTF) printf("_arraySliceSliceMinass_g unittest\n");

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
            c[] -= b[];

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
