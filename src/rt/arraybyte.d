/**
 * Contains SSE2 and MMX versions of certain operations for char, byte, and
 * ubyte ('a', 'g' and 'h' suffixes).
 *
 * Copyright: Copyright Digital Mars 2008 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, based on code originally written by Burton Radons,
 *            Brian Schott (64-bit operations)
 */

/*          Copyright Digital Mars 2008 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.arraybyte;

import core.cpuid;
import rt.util.array;

// debug=PRINTF

version (unittest)
{
    private import core.stdc.stdio : printf;
    /* This is so unit tests will test every CPU variant
     */
    int cpuid;
    const int CPUID_MAX = 4;

nothrow:
    @property bool mmx()      { return cpuid == 1 && core.cpuid.mmx; }
    @property bool sse()      { return cpuid == 2 && core.cpuid.sse; }
    @property bool sse2()     { return cpuid == 3 && core.cpuid.sse2; }
    @property bool amd3dnow() { return cpuid == 4 && core.cpuid.amd3dnow; }
}
else
{
    alias mmx = core.cpuid.mmx;
    alias sse = core.cpuid.sse;
    alias sse2 = core.cpuid.sse2;
    alias amd3dnow = core.cpuid.amd3dnow;
}

//version = log;

alias T = byte;

extern (C) @trusted nothrow:

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
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceExpAddSliceAssign_g()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1088% faster
        if (sse2 && a.length >= 64)
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
        if (mmx && a.length >= 32)
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
    version (D_InlineAsm_X86_64)
    {
        ulong v = (cast(ulong) value) * 0x0101010101010101;
        if (a.length >= 128)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~127);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RDI, simdEnd;
                movq XMM15, v;
                shufpd XMM15, XMM15, 0;

            start64:
                movdqu XMM0, [RBX];
                movdqu XMM1, [RBX + 16];
                movdqu XMM2, [RBX + 32];
                movdqu XMM3, [RBX + 48];
                movdqu XMM4, [RBX + 64];
                movdqu XMM5, [RBX + 80];
                movdqu XMM6, [RBX + 96];
                movdqu XMM7, [RBX + 112];

                paddb XMM0, XMM15;
                paddb XMM1, XMM15;
                paddb XMM2, XMM15;
                paddb XMM3, XMM15;
                paddb XMM4, XMM15;
                paddb XMM5, XMM15;
                paddb XMM6, XMM15;
                paddb XMM7, XMM15;

                movdqu [RAX], XMM0;
                movdqu [RAX + 16], XMM1;
                movdqu [RAX + 32], XMM2;
                movdqu [RAX + 48], XMM3;
                movdqu [RAX + 64], XMM4;
                movdqu [RAX + 80], XMM5;
                movdqu [RAX + 96], XMM6;
                movdqu [RAX + 112], XMM7;

                add RAX, 128;
                add RBX, 128;

                cmp RAX, RDI;
                jb start64;
                mov aptr, RAX;
                mov bptr, RBX;
            }
        }
        if ((aend - aptr) >= 16)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~15);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RDI, simdEnd;
                movq XMM15, v;
                shufpd XMM15, XMM15, 0;
            start16:
                movdqu XMM0, [RBX];
                paddb XMM0, XMM15;
                movdqu [RAX], XMM0;
                add RAX, 16;
                add RBX, 16;
                cmp RAX, RDI;
                jb start16;
                mov aptr, RAX;
                mov bptr, RBX;
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
{
    enforceTypedArraysConformable("vector operation", a, b);
    enforceTypedArraysConformable("vector operation", a, c);

    //printf("_arraySliceSliceAddSliceAssign_g()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 5739% faster
        if (sse2 && a.length >= 64)
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
        if (mmx && a.length >= 32)
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
    version (D_InlineAsm_X86_64)
    {
        if (a.length >= 128)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~127);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RCX, cptr;
                mov RDI, simdEnd;
            start128:

                // Load b
                movdqu XMM0, [RBX];
                movdqu XMM1, [RBX + 16];
                movdqu XMM2, [RBX + 32];
                movdqu XMM3, [RBX + 48];
                movdqu XMM4, [RBX + 64];
                movdqu XMM5, [RBX + 80];
                movdqu XMM6, [RBX + 96];
                movdqu XMM7, [RBX + 112];

                // Load c
                movdqu XMM8, [RCX];
                movdqu XMM9, [RCX + 16];
                movdqu XMM10, [RCX + 32];
                movdqu XMM11, [RCX + 48];
                movdqu XMM12, [RCX + 64];
                movdqu XMM13, [RCX + 80];
                movdqu XMM14, [RCX + 96];
                movdqu XMM15, [RCX + 112];

                // Add
                paddb XMM0, XMM8;
                paddb XMM1, XMM9;
                paddb XMM2, XMM10;
                paddb XMM3, XMM11;
                paddb XMM4, XMM12;
                paddb XMM5, XMM13;
                paddb XMM6, XMM14;
                paddb XMM7, XMM15;

                // Write to a
                movdqu [RAX], XMM0;
                movdqu [RAX + 16], XMM1;
                movdqu [RAX + 32], XMM2;
                movdqu [RAX + 48], XMM3;
                movdqu [RAX + 64], XMM4;
                movdqu [RAX + 80], XMM5;
                movdqu [RAX + 96], XMM6;
                movdqu [RAX + 112], XMM7;

                add RAX, 128;
                add RBX, 128;
                add RCX, 128;

                cmp RAX, RDI;
                jb start128;
                mov aptr, RAX;
                mov bptr, RBX;
                mov cptr, RCX;
            }
        }
        if ((aend - aptr) >= 16)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~15);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RCX, cptr;
                mov RDI, simdEnd;
            start16:
                movdqu XMM0, [RBX];
                movdqu XMM1, [RCX];
                paddb XMM0, XMM1;
                movdqu [RAX], XMM0;
                add RAX, 16;
                add RBX, 16;
                add RCX, 16;
                cmp RAX, RDI;
                jb start16;
                mov aptr, RAX;
                mov bptr, RBX;
                mov cptr, RCX;
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
        if (sse2 && a.length >= 64)
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
        if (mmx && a.length >= 32)
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
    version (D_InlineAsm_X86_64)
    {
        ulong v = (cast(ulong) value) * 0x0101010101010101;
        if (aend - aptr >= 128)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~127);
            asm
            {
                mov RAX, aptr;
                mov RDI, simdEnd;
                movq XMM8, v;
                shufpd XMM8, XMM8, 0;
            start128:
                movdqu XMM0, [RAX];
                paddb XMM0, XMM8;
                movdqu XMM1, [RAX + 16];
                paddb XMM1, XMM8;
                movdqu XMM2, [RAX + 32];
                paddb XMM2, XMM8;
                movdqu XMM3, [RAX + 48];
                paddb XMM3, XMM8;
                movdqu XMM4, [RAX + 64];
                paddb XMM4, XMM8;
                movdqu XMM5, [RAX + 80];
                paddb XMM5, XMM8;
                movdqu XMM6, [RAX + 96];
                paddb XMM6, XMM8;
                movdqu XMM7, [RAX + 112];
                paddb XMM7, XMM8;
                movdqu [RAX], XMM0;
                movdqu [RAX + 16], XMM1;
                movdqu [RAX + 32], XMM2;
                movdqu [RAX + 48], XMM3;
                movdqu [RAX + 64], XMM4;
                movdqu [RAX + 80], XMM5;
                movdqu [RAX + 96], XMM6;
                movdqu [RAX + 112], XMM7;
                add RAX, 128;
                cmp RAX, RDI;
                jb start128;
                mov aptr, RAX;
            }
        }
        if (aend - aptr >= 16)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~15);
            asm
            {
                mov RAX, aptr;
                mov RDI, simdEnd;
                movq XMM4, v;
                shufpd XMM4, XMM4, 0;
            start16:
                movdqu XMM0, [RAX];
                paddb XMM0, XMM4;
                movdqu [RAX], XMM0;
                add RAX, 16;
                cmp RAX, RDI;
                jb start16;
                mov aptr, RAX;
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
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceSliceAddass_g()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 4727% faster
        if (sse2 && a.length >= 64)
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
        if (mmx && a.length >= 32)
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
    version (D_InlineAsm_X86_64)
    {
        if (a.length >= 128)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~127);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RDI, simdEnd;
            start128:

                // Load a
                movdqu XMM0, [RAX];
                movdqu XMM1, [RAX + 16];
                movdqu XMM2, [RAX + 32];
                movdqu XMM3, [RAX + 48];
                movdqu XMM4, [RAX + 64];
                movdqu XMM5, [RAX + 80];
                movdqu XMM6, [RAX + 96];
                movdqu XMM7, [RAX + 112];

                // Load b
                movdqu XMM8, [RBX];
                movdqu XMM9, [RBX + 16];
                movdqu XMM10, [RBX + 32];
                movdqu XMM11, [RBX + 48];
                movdqu XMM12, [RBX + 64];
                movdqu XMM13, [RBX + 80];
                movdqu XMM14, [RBX + 96];
                movdqu XMM15, [RBX + 112];

                // Add
                paddb XMM0, XMM8;
                paddb XMM1, XMM9;
                paddb XMM2, XMM10;
                paddb XMM3, XMM11;
                paddb XMM4, XMM12;
                paddb XMM5, XMM13;
                paddb XMM6, XMM14;
                paddb XMM7, XMM15;

                // Write to a
                movdqu [RAX], XMM0;
                movdqu [RAX + 16], XMM1;
                movdqu [RAX + 32], XMM2;
                movdqu [RAX + 48], XMM3;
                movdqu [RAX + 64], XMM4;
                movdqu [RAX + 80], XMM5;
                movdqu [RAX + 96], XMM6;
                movdqu [RAX + 112], XMM7;

                add RAX, 128;
                add RBX, 128;

                cmp RAX, RDI;
                jb start128;
                mov aptr, RAX;
                mov bptr, RBX;
            }
        }
        if ((aend - aptr) >= 16)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~15);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RDI, simdEnd;
            start16:
                movdqu XMM0, [RAX];
                movdqu XMM1, [RBX];
                paddb XMM0, XMM1;
                movdqu [RAX], XMM0;
                add RAX, 16;
                add RBX, 16;
                cmp RAX, RDI;
                jb start16;
                mov aptr, RAX;
                mov bptr, RBX;
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
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceExpMinSliceAssign_g()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 1189% faster
        if (sse2 && a.length >= 64)
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
        if (mmx && a.length >= 32)
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
    version (D_InlineAsm_X86_64)
    {
        ulong v = (cast(ulong) value) * 0x0101010101010101;
        if (a.length >= 128)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~127);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RDI, simdEnd;
                movq XMM15, v;
                shufpd XMM15, XMM15, 0;

            start64:
                movdqu XMM0, [RBX];
                movdqu XMM1, [RBX + 16];
                movdqu XMM2, [RBX + 32];
                movdqu XMM3, [RBX + 48];
                movdqu XMM4, [RBX + 64];
                movdqu XMM5, [RBX + 80];
                movdqu XMM6, [RBX + 96];
                movdqu XMM7, [RBX + 112];

                psubb XMM0, XMM15;
                psubb XMM1, XMM15;
                psubb XMM2, XMM15;
                psubb XMM3, XMM15;
                psubb XMM4, XMM15;
                psubb XMM5, XMM15;
                psubb XMM6, XMM15;
                psubb XMM7, XMM15;

                movdqu [RAX], XMM0;
                movdqu [RAX + 16], XMM1;
                movdqu [RAX + 32], XMM2;
                movdqu [RAX + 48], XMM3;
                movdqu [RAX + 64], XMM4;
                movdqu [RAX + 80], XMM5;
                movdqu [RAX + 96], XMM6;
                movdqu [RAX + 112], XMM7;

                add RAX, 128;
                add RBX, 128;

                cmp RAX, RDI;
                jb start64;
                mov aptr, RAX;
                mov bptr, RBX;
            }
        }
        if ((aend - aptr) >= 16)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~15);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RDI, simdEnd;
                movq XMM15, v;
                shufpd XMM15, XMM15, 0;
            start16:
                movdqu XMM0, [RBX];
                psubb XMM0, XMM15;
                movdqu [RAX], XMM0;
                add RAX, 16;
                add RBX, 16;
                cmp RAX, RDI;
                jb start16;
                mov aptr, RAX;
                mov bptr, RBX;
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
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arrayExpSliceMinSliceAssign_g()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 8748% faster
        if (sse2 && a.length >= 64)
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
        if (mmx && a.length >= 32)
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
    version (D_InlineAsm_X86_64)
    {
        ulong v = (cast(ulong) value) * 0x0101010101010101;
        if (a.length >= 128)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~127);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RDI, simdEnd;

            start64:
                movq XMM15, v;
                shufpd XMM15, XMM15, 0;
                movdqa XMM8, XMM15;
                movdqa XMM9, XMM15;
                movdqa XMM10, XMM15;
                movdqa XMM11, XMM15;
                movdqa XMM12, XMM15;
                movdqa XMM13, XMM15;
                movdqa XMM14, XMM15;

                movdqu XMM0, [RBX];
                movdqu XMM1, [RBX + 16];
                movdqu XMM2, [RBX + 32];
                movdqu XMM3, [RBX + 48];
                movdqu XMM4, [RBX + 64];
                movdqu XMM5, [RBX + 80];
                movdqu XMM6, [RBX + 96];
                movdqu XMM7, [RBX + 112];

                psubb XMM8, XMM0;
                psubb XMM9, XMM1;
                psubb XMM10, XMM2;
                psubb XMM11, XMM3;
                psubb XMM12, XMM4;
                psubb XMM13, XMM5;
                psubb XMM14, XMM6;
                psubb XMM15, XMM7;

                movdqu [RAX], XMM8;
                movdqu [RAX + 16], XMM9;
                movdqu [RAX + 32], XMM10;
                movdqu [RAX + 48], XMM11;
                movdqu [RAX + 64], XMM12;
                movdqu [RAX + 80], XMM13;
                movdqu [RAX + 96], XMM14;
                movdqu [RAX + 112], XMM15;

                add RAX, 128;
                add RBX, 128;

                cmp RAX, RDI;
                jb start64;
                mov aptr, RAX;
                mov bptr, RBX;
            }
        }
        if ((aend - aptr) >= 16)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~15);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RDI, simdEnd;
            start16:
                movq XMM15, v;
                shufpd XMM15, XMM15, 0;
                movdqu XMM0, [RBX];
                psubb XMM15, XMM0;
                movdqu [RAX], XMM15;
                add RAX, 16;
                add RBX, 16;
                cmp RAX, RDI;
                jb start16;
                mov aptr, RAX;
                mov bptr, RBX;
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
{
    enforceTypedArraysConformable("vector operation", a, b);
    enforceTypedArraysConformable("vector operation", a, c);

    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 5756% faster
        if (sse2 && a.length >= 64)
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
        if (mmx && a.length >= 32)
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
    version (D_InlineAsm_X86_64)
    {
        if (a.length >= 128)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~127);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RCX, cptr;
                mov RDI, simdEnd;
            start128:

                // Load b
                movdqu XMM0, [RBX];
                movdqu XMM1, [RBX + 16];
                movdqu XMM2, [RBX + 32];
                movdqu XMM3, [RBX + 48];
                movdqu XMM4, [RBX + 64];
                movdqu XMM5, [RBX + 80];
                movdqu XMM6, [RBX + 96];
                movdqu XMM7, [RBX + 112];

                // Load c
                movdqu XMM8, [RCX];
                movdqu XMM9, [RCX + 16];
                movdqu XMM10, [RCX + 32];
                movdqu XMM11, [RCX + 48];
                movdqu XMM12, [RCX + 64];
                movdqu XMM13, [RCX + 80];
                movdqu XMM14, [RCX + 96];
                movdqu XMM15, [RCX + 112];

                // Subtract
                psubb XMM0, XMM8;
                psubb XMM1, XMM9;
                psubb XMM2, XMM10;
                psubb XMM3, XMM11;
                psubb XMM4, XMM12;
                psubb XMM5, XMM13;
                psubb XMM6, XMM14;
                psubb XMM7, XMM15;

                // Write to a
                movdqu [RAX], XMM0;
                movdqu [RAX + 16], XMM1;
                movdqu [RAX + 32], XMM2;
                movdqu [RAX + 48], XMM3;
                movdqu [RAX + 64], XMM4;
                movdqu [RAX + 80], XMM5;
                movdqu [RAX + 96], XMM6;
                movdqu [RAX + 112], XMM7;

                add RAX, 128;
                add RBX, 128;
                add RCX, 128;

                cmp RAX, RDI;
                jb start128;
                mov aptr, RAX;
                mov bptr, RBX;
                mov cptr, RCX;
            }
        }
        if ((aend - aptr) >= 16)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~15);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RCX, cptr;
                mov RDI, simdEnd;
            start16:
                movdqu XMM0, [RBX];
                movdqu XMM1, [RCX];
                psubb XMM0, XMM1;
                movdqu [RAX], XMM0;
                add RAX, 16;
                add RBX, 16;
                add RCX, 16;
                cmp RAX, RDI;
                jb start16;
                mov aptr, RAX;
                mov bptr, RBX;
                mov cptr, RCX;
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
        if (sse2 && a.length >= 64)
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
        if (mmx && a.length >= 32)
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
    version (D_InlineAsm_X86_64)
    {
        ulong v = (cast(ulong) value) * 0x0101010101010101;
        if (aend - aptr >= 128)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~127);
            asm
            {
                mov RAX, aptr;
                mov RDI, simdEnd;
                pshufd XMM8, XMM8, 0;
                movq XMM8, v;
                shufpd XMM8, XMM8, 0;
            start128:
                movdqu XMM0, [RAX];
                psubb XMM0, XMM8;
                movdqu XMM1, [RAX + 16];
                psubb XMM1, XMM8;
                movdqu XMM2, [RAX + 32];
                psubb XMM2, XMM8;
                movdqu XMM3, [RAX + 48];
                psubb XMM3, XMM8;
                movdqu XMM4, [RAX + 64];
                psubb XMM4, XMM8;
                movdqu XMM5, [RAX + 80];
                psubb XMM5, XMM8;
                movdqu XMM6, [RAX + 96];
                psubb XMM6, XMM8;
                movdqu XMM7, [RAX + 112];
                psubb XMM7, XMM8;
                movdqu [RAX], XMM0;
                movdqu [RAX + 16], XMM1;
                movdqu [RAX + 32], XMM2;
                movdqu [RAX + 48], XMM3;
                movdqu [RAX + 64], XMM4;
                movdqu [RAX + 80], XMM5;
                movdqu [RAX + 96], XMM6;
                movdqu [RAX + 112], XMM7;
                add RAX, 128;
                cmp RAX, RDI;
                jb start128;
                mov aptr, RAX;
            }
        }
        if (aend - aptr >= 16)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~15);
            asm
            {
                mov RAX, aptr;
                mov RDI, simdEnd;
                movq XMM4, v;
                shufpd XMM4, XMM4, 0;
            start16:
                movdqu XMM0, [RAX];
                psubb XMM0, XMM4;
                movdqu [RAX], XMM0;
                add RAX, 16;
                cmp RAX, RDI;
                jb start16;
                mov aptr, RAX;
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
{
    enforceTypedArraysConformable("vector operation", a, b);

    //printf("_arraySliceSliceMinass_g()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 aligned version is 4800% faster
        if (sse2 && a.length >= 64)
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
        if (mmx && a.length >= 32)
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
    version (D_InlineAsm_X86_64)
    {
        if (a.length >= 128)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~127);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RDI, simdEnd;
            start128:

                // Load a
                movdqu XMM0, [RAX];
                movdqu XMM1, [RAX + 16];
                movdqu XMM2, [RAX + 32];
                movdqu XMM3, [RAX + 48];
                movdqu XMM4, [RAX + 64];
                movdqu XMM5, [RAX + 80];
                movdqu XMM6, [RAX + 96];
                movdqu XMM7, [RAX + 112];

                // Load b
                movdqu XMM8, [RBX];
                movdqu XMM9, [RBX + 16];
                movdqu XMM10, [RBX + 32];
                movdqu XMM11, [RBX + 48];
                movdqu XMM12, [RBX + 64];
                movdqu XMM13, [RBX + 80];
                movdqu XMM14, [RBX + 96];
                movdqu XMM15, [RBX + 112];

                // Subtract
                psubb XMM0, XMM8;
                psubb XMM1, XMM9;
                psubb XMM2, XMM10;
                psubb XMM3, XMM11;
                psubb XMM4, XMM12;
                psubb XMM5, XMM13;
                psubb XMM6, XMM14;
                psubb XMM7, XMM15;

                // Write to a
                movdqu [RAX], XMM0;
                movdqu [RAX + 16], XMM1;
                movdqu [RAX + 32], XMM2;
                movdqu [RAX + 48], XMM3;
                movdqu [RAX + 64], XMM4;
                movdqu [RAX + 80], XMM5;
                movdqu [RAX + 96], XMM6;
                movdqu [RAX + 112], XMM7;

                add RAX, 128;
                add RBX, 128;

                cmp RAX, RDI;
                jb start128;
                mov aptr, RAX;
                mov bptr, RBX;
            }
        }
        if ((aend - aptr) >= 16)
        {
            size_t simdEnd = (cast(size_t) aptr) + (a.length & ~15);
            asm
            {
                mov RAX, aptr;
                mov RBX, bptr;
                mov RDI, simdEnd;
            start16:
                movdqu XMM0, [RAX];
                movdqu XMM1, [RBX];
                psubb XMM0, XMM1;
                movdqu [RAX], XMM0;
                add RAX, 16;
                add RBX, 16;
                cmp RAX, RDI;
                jb start16;
                mov aptr, RAX;
                mov bptr, RBX;
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
