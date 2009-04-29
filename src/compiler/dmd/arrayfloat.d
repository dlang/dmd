/**
 * Contains SSE2 and MMX versions of certain operations for float.
 *
 * Copyright: Copyright Digital Mars 2008 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt>Boost License 1.0</a>.
 * Authors:   Walter Bright, based on code originally written by Burton Radons
 *
 *          Copyright Digital Mars 2008 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.arrayfloat;

private import rt.util.cpuid;

version (unittest)
{
    private import core.stdc.stdio : printf;
    /* This is so unit tests will test every CPU variant
     */
    int cpuid;
    const int CPUID_MAX = 5;
    bool mmx()      { return cpuid == 1 && rt.util.cpuid.mmx(); }
    bool sse()      { return cpuid == 2 && rt.util.cpuid.sse(); }
    bool sse2()     { return cpuid == 3 && rt.util.cpuid.sse2(); }
    bool amd3dnow() { return cpuid == 4 && rt.util.cpuid.amd3dnow(); }
}
else
{
    alias rt.util.cpuid.mmx mmx;
    alias rt.util.cpuid.sse sse;
    alias rt.util.cpuid.sse2 sse2;
    alias rt.util.cpuid.amd3dnow amd3dnow;
}

//version = log;

bool disjoint(T)(T[] a, T[] b)
{
    return (a.ptr + a.length <= b.ptr || b.ptr + b.length <= a.ptr);
}

alias float T;

extern (C):

/* ======================================================================== */

/***********************
 * Computes:
 *      a[] = b[] + c[]
 */

T[] _arraySliceSliceAddSliceAssign_f(T[] a, T[] c, T[] b)
in
{
        assert(a.length == b.length && b.length == c.length);
        assert(disjoint(a, b));
        assert(disjoint(a, c));
        assert(disjoint(b, c));
}
body
{
    //printf("_arraySliceSliceAddSliceAssign_f()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE version is 834% faster
        if (sse() && b.length >= 16)
        {
            version (log) printf("\tsse unaligned\n");
            auto n = aptr + (b.length & ~15);

            // Unaligned case
            asm
            {
                mov EAX, bptr; // left operand
                mov ECX, cptr; // right operand
                mov ESI, aptr; // destination operand
                mov EDI, n;    // end comparison

                align 8;
            startsseloopb:
                movups XMM0, [EAX];
                movups XMM1, [EAX+16];
                movups XMM2, [EAX+32];
                movups XMM3, [EAX+48];
                add EAX, 64;
                movups XMM4, [ECX];
                movups XMM5, [ECX+16];
                movups XMM6, [ECX+32];
                movups XMM7, [ECX+48];
                add ESI, 64;
                addps XMM0, XMM4;
                addps XMM1, XMM5;
                addps XMM2, XMM6;
                addps XMM3, XMM7;
                add ECX, 64;
                movups [ESI+ 0-64], XMM0;
                movups [ESI+16-64], XMM1;
                movups [ESI+32-64], XMM2;
                movups [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopb;

                mov aptr, ESI;
                mov bptr, EAX;
                mov cptr, ECX;
            }
        }
        else
        // 3DNow! version is only 13% faster
        if (amd3dnow() && b.length >= 8)
        {
            version (log) printf("\tamd3dnow\n");
            auto n = aptr + (b.length & ~7);

            asm
            {
                mov ESI, aptr; // destination operand
                mov EDI, n;    // end comparison
                mov EAX, bptr; // left operand
                mov ECX, cptr; // right operand

                align 4;
            start3dnow:
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                pfadd MM0, [ECX];
                pfadd MM1, [ECX+8];
                pfadd MM2, [ECX+16];
                pfadd MM3, [ECX+24];
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ECX, 32;
                add ESI, 32;
                add EAX, 32;
                cmp ESI, EDI;
                jb start3dnow;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
                mov cptr, ECX;
            }
        }
    }

    // Handle remainder
    version (log) if (aptr < aend) printf("\tbase\n");
    while (aptr < aend)
        *aptr++ = *bptr++ + *cptr++;

    return a;
}


unittest
{
    printf("_arraySliceSliceAddSliceAssign_f unittest\n");
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
                    printf("[%d]: %g != %g + %g\n", i, c[i], a[i], b[i]);
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

T[] _arraySliceSliceMinSliceAssign_f(T[] a, T[] c, T[] b)
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
        // SSE version is 834% faster
        if (sse() && b.length >= 16)
        {
            auto n = aptr + (b.length & ~15);

            // Unaligned case
            asm
            {
                mov EAX, bptr; // left operand
                mov ECX, cptr; // right operand
                mov ESI, aptr; // destination operand
                mov EDI, n;    // end comparison

                align 8;
            startsseloopb:
                movups XMM0, [EAX];
                movups XMM1, [EAX+16];
                movups XMM2, [EAX+32];
                movups XMM3, [EAX+48];
                add EAX, 64;
                movups XMM4, [ECX];
                movups XMM5, [ECX+16];
                movups XMM6, [ECX+32];
                movups XMM7, [ECX+48];
                add ESI, 64;
                subps XMM0, XMM4;
                subps XMM1, XMM5;
                subps XMM2, XMM6;
                subps XMM3, XMM7;
                add ECX, 64;
                movups [ESI+ 0-64], XMM0;
                movups [ESI+16-64], XMM1;
                movups [ESI+32-64], XMM2;
                movups [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopb;

                mov aptr, ESI;
                mov bptr, EAX;
                mov cptr, ECX;
            }
        }
        else
        // 3DNow! version is only 13% faster
        if (amd3dnow() && b.length >= 8)
        {
            auto n = aptr + (b.length & ~7);

            asm
            {
                mov ESI, aptr; // destination operand
                mov EDI, n;    // end comparison
                mov EAX, bptr; // left operand
                mov ECX, cptr; // right operand

                align 4;
            start3dnow:
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                pfsub MM0, [ECX];
                pfsub MM1, [ECX+8];
                pfsub MM2, [ECX+16];
                pfsub MM3, [ECX+24];
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ECX, 32;
                add ESI, 32;
                add EAX, 32;
                cmp ESI, EDI;
                jb start3dnow;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
                mov cptr, ECX;
            }
        }
    }

    // Handle remainder
    while (aptr < aend)
        *aptr++ = *bptr++ - *cptr++;

    return a;
}


unittest
{
    printf("_arraySliceSliceMinSliceAssign_f unittest\n");
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
                    printf("[%d]: %g != %gd - %g\n", i, c[i], a[i], b[i]);
                    assert(0);
                }
            }
        }
    }
}

/* ======================================================================== */

/***********************
 * Computes:
 *      a[] = b[] + value
 */

T[] _arraySliceExpAddSliceAssign_f(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpAddSliceAssign_f()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE version is 665% faster
        if (sse() && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            // Unaligned case
            asm
            {
                mov EAX, bptr;
                mov ESI, aptr;
                mov EDI, n;
                movss XMM4, value;
                shufps XMM4, XMM4, 0;

                align 8;
            startsseloop:
                add ESI, 64;
                movups XMM0, [EAX];
                movups XMM1, [EAX+16];
                movups XMM2, [EAX+32];
                movups XMM3, [EAX+48];
                add EAX, 64;
                addps XMM0, XMM4;
                addps XMM1, XMM4;
                addps XMM2, XMM4;
                addps XMM3, XMM4;
                movups [ESI+ 0-64], XMM0;
                movups [ESI+16-64], XMM1;
                movups [ESI+32-64], XMM2;
                movups [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloop;

                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
        else
        // 3DNow! version is 69% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            ulong w = *cast(uint *) &value;
            ulong v = w | (w << 32L);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                movq MM4, qword ptr [v];

                align 8;
            start3dnow:
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                pfadd MM0, MM4;
                pfadd MM1, MM4;
                pfadd MM2, MM4;
                pfadd MM3, MM4;
                movq [ESI],    MM0;
                movq [ESI+8],  MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ESI, 32;
                add EAX, 32;
                cmp ESI, EDI;
                jb start3dnow;

                emms;
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
    printf("_arraySliceExpAddSliceAssign_f unittest\n");
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
                    printf("[%d]: %g != %g + 6\n", i, c[i], a[i]);
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

T[] _arrayExpSliceAddass_f(T[] a, T value)
{
    //printf("_arrayExpSliceAddass_f(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE version is 302% faster
        if (sse() && a.length >= 16)
        {
            // align pointer
            auto n = cast(T*)((cast(uint)aptr + 15) & ~15);
            while (aptr < n)
                *aptr++ += value;
            n = cast(T*)((cast(uint)aend) & ~15);
            if (aptr < n)

            // Aligned case
            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movss XMM4, value;
                shufps XMM4, XMM4, 0;

                align 8;
            startsseloopa:
                movaps XMM0, [ESI];
                movaps XMM1, [ESI+16];
                movaps XMM2, [ESI+32];
                movaps XMM3, [ESI+48];
                add ESI, 64;
                addps XMM0, XMM4;
                addps XMM1, XMM4;
                addps XMM2, XMM4;
                addps XMM3, XMM4;
                movaps [ESI+ 0-64], XMM0;
                movaps [ESI+16-64], XMM1;
                movaps [ESI+32-64], XMM2;
                movaps [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopa;

                mov aptr, ESI;
            }
        }
        else
        // 3DNow! version is 63% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            ulong w = *cast(uint *) &value;
            ulong v = w | (w << 32L);

            asm
            {
                mov ESI, dword ptr [aptr];
                mov EDI, dword ptr [n];
                movq MM4, qword ptr [v];

                align 8;
            start3dnow:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                movq MM2, [ESI+16];
                movq MM3, [ESI+24];
                pfadd MM0, MM4;
                pfadd MM1, MM4;
                pfadd MM2, MM4;
                pfadd MM3, MM4;
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ESI, 32;
                cmp ESI, EDI;
                jb start3dnow;

                emms;
                mov dword ptr [aptr], ESI;
            }
        }
    }

    while (aptr < aend)
        *aptr++ += value;

    return a;
}

unittest
{
    printf("_arrayExpSliceAddass_f unittest\n");
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
                    printf("[%d]: %g != %g + 6\n", i, c[i], a[i]);
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

T[] _arraySliceSliceAddass_f(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceAddass_f()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE version is 468% faster
        if (sse() && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            // Unaligned case
            asm
            {
                mov ECX, bptr; // right operand
                mov ESI, aptr; // destination operand
                mov EDI, n; // end comparison

                align 8;
            startsseloopb:
                movups XMM0, [ESI];
                movups XMM1, [ESI+16];
                movups XMM2, [ESI+32];
                movups XMM3, [ESI+48];
                add ESI, 64;
                movups XMM4, [ECX];
                movups XMM5, [ECX+16];
                movups XMM6, [ECX+32];
                movups XMM7, [ECX+48];
                add ECX, 64;
                addps XMM0, XMM4;
                addps XMM1, XMM5;
                addps XMM2, XMM6;
                addps XMM3, XMM7;
                movups [ESI+ 0-64], XMM0;
                movups [ESI+16-64], XMM1;
                movups [ESI+32-64], XMM2;
                movups [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopb;

                mov aptr, ESI;
                mov bptr, ECX;
            }
        }
        else
        // 3DNow! version is 57% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            asm
            {
                mov ESI, dword ptr [aptr]; // destination operand
                mov EDI, dword ptr [n];    // end comparison
                mov ECX, dword ptr [bptr]; // right operand

                align 4;
            start3dnow:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                movq MM2, [ESI+16];
                movq MM3, [ESI+24];
                pfadd MM0, [ECX];
                pfadd MM1, [ECX+8];
                pfadd MM2, [ECX+16];
                pfadd MM3, [ECX+24];
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ESI, 32;
                add ECX, 32;
                cmp ESI, EDI;
                jb start3dnow;

                emms;
                mov dword ptr [aptr], ESI;
                mov dword ptr [bptr], ECX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ += *bptr++;

    return a;
}

unittest
{
    printf("_arraySliceSliceAddass_f unittest\n");
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
                    printf("[%d]: %g != %g + %g\n", i, c[i], a[i], b[i]);
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

T[] _arraySliceExpMinSliceAssign_f(T[] a, T value, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceExpMinSliceAssign_f()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE version is 622% faster
        if (sse() && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            // Unaligned case
            asm
            {
                mov EAX, bptr;
                mov ESI, aptr;
                mov EDI, n;
                movss XMM4, value;
                shufps XMM4, XMM4, 0;

                align 8;
            startsseloop:
                add ESI, 64;
                movups XMM0, [EAX];
                movups XMM1, [EAX+16];
                movups XMM2, [EAX+32];
                movups XMM3, [EAX+48];
                add EAX, 64;
                subps XMM0, XMM4;
                subps XMM1, XMM4;
                subps XMM2, XMM4;
                subps XMM3, XMM4;
                movups [ESI+ 0-64], XMM0;
                movups [ESI+16-64], XMM1;
                movups [ESI+32-64], XMM2;
                movups [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloop;

                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
        else
        // 3DNow! version is 67% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            T[2] w;

            w[0] = w[1] = value;

            asm
            {
                mov ESI, dword ptr [aptr];
                mov EDI, dword ptr [n];
                mov EAX, dword ptr [bptr];
                movq MM4, qword ptr [w];

                align 8;
            start3dnow:
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                pfsub MM0, MM4;
                pfsub MM1, MM4;
                pfsub MM2, MM4;
                pfsub MM3, MM4;
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ESI, 32;
                add EAX, 32;
                cmp ESI, EDI;
                jb start3dnow;

                emms;
                mov dword ptr [aptr], ESI;
                mov dword ptr [bptr], EAX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ = *bptr++ - value;

    return a;
}

unittest
{
    printf("_arraySliceExpMinSliceAssign_f unittest\n");
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
                    printf("[%d]: %g != %g - 6\n", i, c[i], a[i]);
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

T[] _arrayExpSliceMinSliceAssign_f(T[] a, T[] b, T value)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arrayExpSliceMinSliceAssign_f()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE version is 690% faster
        if (sse() && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            // Unaligned case
            asm
            {
                mov EAX, bptr;
                mov ESI, aptr;
                mov EDI, n;
                movss XMM4, value;
                shufps XMM4, XMM4, 0;

                align 8;
            startsseloop:
                add ESI, 64;
                movaps XMM5, XMM4;
                movaps XMM6, XMM4;
                movups XMM0, [EAX];
                movups XMM1, [EAX+16];
                movups XMM2, [EAX+32];
                movups XMM3, [EAX+48];
                add EAX, 64;
                subps XMM5, XMM0;
                subps XMM6, XMM1;
                movups [ESI+ 0-64], XMM5;
                movups [ESI+16-64], XMM6;
                movaps XMM5, XMM4;
                movaps XMM6, XMM4;
                subps XMM5, XMM2;
                subps XMM6, XMM3;
                movups [ESI+32-64], XMM5;
                movups [ESI+48-64], XMM6;
                cmp ESI, EDI;
                jb startsseloop;

                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
        else
        // 3DNow! version is 67% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            ulong w = *cast(uint *) &value;
            ulong v = w | (w << 32L);

            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                mov EAX, bptr;
                movq MM4, qword ptr [v];

                align 8;
            start3dnow:
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                pfsubr MM0, MM4;
                pfsubr MM1, MM4;
                pfsubr MM2, MM4;
                pfsubr MM3, MM4;
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ESI, 32;
                add EAX, 32;
                cmp ESI, EDI;
                jb start3dnow;

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
    printf("_arrayExpSliceMinSliceAssign_f unittest\n");
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
                    printf("[%d]: %g != 6 - %g\n", i, c[i], a[i]);
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

T[] _arrayExpSliceMinass_f(T[] a, T value)
{
    //printf("_arrayExpSliceMinass_f(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE version is 304% faster
        if (sse() && a.length >= 16)
        {
            // align pointer
            auto n = cast(T*)((cast(uint)aptr + 15) & ~15);
            while (aptr < n)
                *aptr++ -= value;
            n = cast(T*)((cast(uint)aend) & ~15);
            if (aptr < n)

            // Aligned case
            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movss XMM4, value;
                shufps XMM4, XMM4, 0;

                align 8;
            startsseloopa:
                movaps XMM0, [ESI];
                movaps XMM1, [ESI+16];
                movaps XMM2, [ESI+32];
                movaps XMM3, [ESI+48];
                add ESI, 64;
                subps XMM0, XMM4;
                subps XMM1, XMM4;
                subps XMM2, XMM4;
                subps XMM3, XMM4;
                movaps [ESI+ 0-64], XMM0;
                movaps [ESI+16-64], XMM1;
                movaps [ESI+32-64], XMM2;
                movaps [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopa;

                mov aptr, ESI;
            }
        }
        else
        // 3DNow! version is 63% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            ulong w = *cast(uint *) &value;
            ulong v = w | (w << 32L);

            asm
            {
                mov ESI, dword ptr [aptr];
                mov EDI, dword ptr [n];
                movq MM4, qword ptr [v];

                align 8;
            start:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                movq MM2, [ESI+16];
                movq MM3, [ESI+24];
                pfsub MM0, MM4;
                pfsub MM1, MM4;
                pfsub MM2, MM4;
                pfsub MM3, MM4;
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ESI, 32;
                cmp ESI, EDI;
                jb start;

                emms;
                mov dword ptr [aptr], ESI;
            }
        }
    }

    while (aptr < aend)
        *aptr++ -= value;

    return a;
}

unittest
{
    printf("_arrayExpSliceminass_f unittest\n");
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
                    printf("[%d]: %g != %g - 6\n", i, c[i], a[i]);
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

T[] _arraySliceSliceMinass_f(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceMinass_f()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE version is 468% faster
        if (sse() && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            // Unaligned case
            asm
            {
                mov ECX, bptr; // right operand
                mov ESI, aptr; // destination operand
                mov EDI, n; // end comparison

                align 8;
            startsseloopb:
                movups XMM0, [ESI];
                movups XMM1, [ESI+16];
                movups XMM2, [ESI+32];
                movups XMM3, [ESI+48];
                add ESI, 64;
                movups XMM4, [ECX];
                movups XMM5, [ECX+16];
                movups XMM6, [ECX+32];
                movups XMM7, [ECX+48];
                add ECX, 64;
                subps XMM0, XMM4;
                subps XMM1, XMM5;
                subps XMM2, XMM6;
                subps XMM3, XMM7;
                movups [ESI+ 0-64], XMM0;
                movups [ESI+16-64], XMM1;
                movups [ESI+32-64], XMM2;
                movups [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopb;

                mov aptr, ESI;
                mov bptr, ECX;
            }
        }
        else
        // 3DNow! version is 57% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            asm
            {
                mov ESI, dword ptr [aptr]; // destination operand
                mov EDI, dword ptr [n]; // end comparison
                mov ECX, dword ptr [bptr]; // right operand

                align 4;
            start:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                movq MM2, [ESI+16];
                movq MM3, [ESI+24];
                pfsub MM0, [ECX];
                pfsub MM1, [ECX+8];
                pfsub MM2, [ECX+16];
                pfsub MM3, [ECX+24];
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ESI, 32;
                add ECX, 32;
                cmp ESI, EDI;
                jb start;

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
    printf("_arrayExpSliceMinass_f unittest\n");
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
                    printf("[%d]: %g != %g - 6\n", i, c[i], a[i]);
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

T[] _arraySliceExpMulSliceAssign_f(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpMulSliceAssign_f()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE version is 607% faster
        if (sse() && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            // Unaligned case
            asm
            {
                mov EAX, bptr;
                mov ESI, aptr;
                mov EDI, n;
                movss XMM4, value;
                shufps XMM4, XMM4, 0;

                align 8;
            startsseloop:
                add ESI, 64;
                movups XMM0, [EAX];
                movups XMM1, [EAX+16];
                movups XMM2, [EAX+32];
                movups XMM3, [EAX+48];
                add EAX, 64;
                mulps XMM0, XMM4;
                mulps XMM1, XMM4;
                mulps XMM2, XMM4;
                mulps XMM3, XMM4;
                movups [ESI+ 0-64], XMM0;
                movups [ESI+16-64], XMM1;
                movups [ESI+32-64], XMM2;
                movups [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloop;

                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
        else
        // 3DNow! version is 69% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            ulong w = *cast(uint *) &value;
            ulong v = w | (w << 32L);

            asm
            {
                mov ESI, dword ptr [aptr];
                mov EDI, dword ptr [n];
                mov EAX, dword ptr [bptr];
                movq MM4, qword ptr [v];

                align 8;
            start:
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                pfmul MM0, MM4;
                pfmul MM1, MM4;
                pfmul MM2, MM4;
                pfmul MM3, MM4;
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ESI, 32;
                add EAX, 32;
                cmp ESI, EDI;
                jb start;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ = *bptr++ * value;

    return a;
}

unittest
{
    printf("_arraySliceExpMulSliceAssign_f unittest\n");
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
                    printf("[%d]: %g != %g * 6\n", i, c[i], a[i]);
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

T[] _arraySliceSliceMulSliceAssign_f(T[] a, T[] c, T[] b)
in
{
        assert(a.length == b.length && b.length == c.length);
        assert(disjoint(a, b));
        assert(disjoint(a, c));
        assert(disjoint(b, c));
}
body
{
    //printf("_arraySliceSliceMulSliceAssign_f()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE version is 833% faster
        if (sse() && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            // Unaligned case
            asm
            {
                mov EAX, bptr; // left operand
                mov ECX, cptr; // right operand
                mov ESI, aptr; // destination operand
                mov EDI, n; // end comparison

                align 8;
            startsseloopb:
                movups XMM0, [EAX];
                movups XMM1, [EAX+16];
                movups XMM2, [EAX+32];
                movups XMM3, [EAX+48];
                add ESI, 64;
                movups XMM4, [ECX];
                movups XMM5, [ECX+16];
                movups XMM6, [ECX+32];
                movups XMM7, [ECX+48];
                add EAX, 64;
                mulps XMM0, XMM4;
                mulps XMM1, XMM5;
                mulps XMM2, XMM6;
                mulps XMM3, XMM7;
                add ECX, 64;
                movups [ESI+ 0-64], XMM0;
                movups [ESI+16-64], XMM1;
                movups [ESI+32-64], XMM2;
                movups [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopb;

                mov aptr, ESI;
                mov bptr, EAX;
                mov cptr, ECX;
            }
        }
        else
        // 3DNow! version is only 13% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            asm
            {
                mov ESI, dword ptr [aptr]; // destination operand
                mov EDI, dword ptr [n]; // end comparison
                mov EAX, dword ptr [bptr]; // left operand
                mov ECX, dword ptr [cptr]; // right operand

                align 4;
            start:
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                pfmul MM0, [ECX];
                pfmul MM1, [ECX+8];
                pfmul MM2, [ECX+16];
                pfmul MM3, [ECX+24];
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ECX, 32;
                add ESI, 32;
                add EAX, 32;
                cmp ESI, EDI;
                jb start;

                emms;
                mov aptr, ESI;
                mov bptr, EAX;
                mov cptr, ECX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ = *bptr++ * *cptr++;

    return a;
}

unittest
{
    printf("_arraySliceSliceMulSliceAssign_f unittest\n");
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
                    printf("[%d]: %g != %g * %g\n", i, c[i], a[i], b[i]);
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

T[] _arrayExpSliceMulass_f(T[] a, T value)
{
    //printf("_arrayExpSliceMulass_f(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE version is 303% faster
        if (sse() && a.length >= 16)
        {
            // align pointer
            auto n = cast(T*)((cast(uint)aptr + 15) & ~15);
            while (aptr < n)
                *aptr++ *= value;
            n = cast(T*)((cast(uint)aend) & ~15);
            if (aptr < n)

            // Aligned case
            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movss XMM4, value;
                shufps XMM4, XMM4, 0;

                align 8;
            startsseloopa:
                movaps XMM0, [ESI];
                movaps XMM1, [ESI+16];
                movaps XMM2, [ESI+32];
                movaps XMM3, [ESI+48];
                add ESI, 64;
                mulps XMM0, XMM4;
                mulps XMM1, XMM4;
                mulps XMM2, XMM4;
                mulps XMM3, XMM4;
                movaps [ESI+ 0-64], XMM0;
                movaps [ESI+16-64], XMM1;
                movaps [ESI+32-64], XMM2;
                movaps [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopa;

                mov aptr, ESI;
            }
        }
        else
        // 3DNow! version is 63% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            ulong w = *cast(uint *) &value;
            ulong v = w | (w << 32L);

            asm
            {
                mov ESI, dword ptr [aptr];
                mov EDI, dword ptr [n];
                movq MM4, qword ptr [v];

                align 8;
            start:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                movq MM2, [ESI+16];
                movq MM3, [ESI+24];
                pfmul MM0, MM4;
                pfmul MM1, MM4;
                pfmul MM2, MM4;
                pfmul MM3, MM4;
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ESI, 32;
                cmp ESI, EDI;
                jb start;

                emms;
                mov dword ptr [aptr], ESI;
            }
        }
    }

    while (aptr < aend)
        *aptr++ *= value;

    return a;
}

unittest
{
    printf("_arrayExpSliceMulass_f unittest\n");
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
            c[] *= 6;

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(a[i] * 6))
                {
                    printf("[%d]: %g != %g * 6\n", i, c[i], a[i]);
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

T[] _arraySliceSliceMulass_f(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceMulass_f()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE version is 525% faster
        if (sse() && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            // Unaligned case
            asm
            {
                mov ECX, bptr; // right operand
                mov ESI, aptr; // destination operand
                mov EDI, n; // end comparison

                align 8;
            startsseloopb:
                movups XMM0, [ESI];
                movups XMM1, [ESI+16];
                movups XMM2, [ESI+32];
                movups XMM3, [ESI+48];
                add ESI, 64;
                movups XMM4, [ECX];
                movups XMM5, [ECX+16];
                movups XMM6, [ECX+32];
                movups XMM7, [ECX+48];
                add ECX, 64;
                mulps XMM0, XMM4;
                mulps XMM1, XMM5;
                mulps XMM2, XMM6;
                mulps XMM3, XMM7;
                movups [ESI+ 0-64], XMM0;
                movups [ESI+16-64], XMM1;
                movups [ESI+32-64], XMM2;
                movups [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopb;

                mov aptr, ESI;
                mov bptr, ECX;
            }
        }
        else
        // 3DNow! version is 57% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            asm
            {
                mov ESI, dword ptr [aptr]; // destination operand
                mov EDI, dword ptr [n]; // end comparison
                mov ECX, dword ptr [bptr]; // right operand

                align 4;
            start:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                movq MM2, [ESI+16];
                movq MM3, [ESI+24];
                pfmul MM0, [ECX];
                pfmul MM1, [ECX+8];
                pfmul MM2, [ECX+16];
                pfmul MM3, [ECX+24];
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ESI, 32;
                add ECX, 32;
                cmp ESI, EDI;
                jb start;

                emms;
                mov dword ptr [aptr], ESI;
                mov dword ptr [bptr], ECX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ *= *bptr++;

    return a;
}

unittest
{
    printf("_arrayExpSliceMulass_f unittest\n");
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
            c[] *= 6;

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(a[i] * 6))
                {
                    printf("[%d]: %g != %g * 6\n", i, c[i], a[i]);
                    assert(0);
                }
            }
        }
    }
}

/* ======================================================================== */

/***********************
 * Computes:
 *      a[] = b[] / value
 */

T[] _arraySliceExpDivSliceAssign_f(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpDivSliceAssign_f()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    /* Multiplying by the reciprocal is faster, but does
     * not produce as accurate an answer.
     */
    T recip = cast(T)1 / value;

    version (D_InlineAsm_X86)
    {
        // SSE version is 587% faster
        if (sse() && a.length >= 16)
        {
            auto n = aptr + (a.length & ~15);

            // Unaligned case
            asm
            {
                mov EAX, bptr;
                mov ESI, aptr;
                mov EDI, n;
                movss XMM4, recip;
                //movss XMM4, value
                //rcpss XMM4, XMM4
                shufps XMM4, XMM4, 0;

                align 8;
            startsseloop:
                add ESI, 64;
                movups XMM0, [EAX];
                movups XMM1, [EAX+16];
                movups XMM2, [EAX+32];
                movups XMM3, [EAX+48];
                add EAX, 64;
                mulps XMM0, XMM4;
                mulps XMM1, XMM4;
                mulps XMM2, XMM4;
                mulps XMM3, XMM4;
                //divps XMM0, XMM4;
                //divps XMM1, XMM4;
                //divps XMM2, XMM4;
                //divps XMM3, XMM4;
                movups [ESI+ 0-64], XMM0;
                movups [ESI+16-64], XMM1;
                movups [ESI+32-64], XMM2;
                movups [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloop;

                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
        else
        // 3DNow! version is 72% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            T[2] w = void;

            w[0] = recip;
            w[1] = recip;

            asm
            {
                mov ESI, dword ptr [aptr];
                mov EDI, dword ptr [n];
                mov EAX, dword ptr [bptr];
                movq MM4, qword ptr [w];

                align 8;
            start:
                movq MM0, [EAX];
                movq MM1, [EAX+8];
                movq MM2, [EAX+16];
                movq MM3, [EAX+24];
                pfmul MM0, MM4;
                pfmul MM1, MM4;
                pfmul MM2, MM4;
                pfmul MM3, MM4;
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ESI, 32;
                add EAX, 32;
                cmp ESI, EDI;
                jb start;

                emms;
                mov dword ptr [aptr], ESI;
                mov dword ptr [bptr], EAX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ = *bptr++ * recip;

    return a;
}

unittest
{
    printf("_arraySliceExpDivSliceAssign_f unittest\n");
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

            c[] = a[] / 8;

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(a[i] / 8))
                {
                    printf("[%d]: %g != %g / 8\n", i, c[i], a[i]);
                    assert(0);
                }
            }
        }
    }
}

/* ======================================================================== */

/***********************
 * Computes:
 *      a[] /= value
 */

T[] _arrayExpSliceDivass_f(T[] a, T value)
{
    //printf("_arrayExpSliceDivass_f(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    /* Multiplying by the reciprocal is faster, but does
     * not produce as accurate an answer.
     */
    T recip = cast(T)1 / value;

    version (D_InlineAsm_X86)
    {
        // SSE version is 245% faster
        if (sse() && a.length >= 16)
        {
            // align pointer
            auto n = cast(T*)((cast(uint)aptr + 15) & ~15);
            while (aptr < n)
                *aptr++ *= recip;
            n = cast(T*)((cast(uint)aend) & ~15);
            if (aptr < n)

            // Aligned case
            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movss XMM4, recip;
                //movss XMM4, value
                //rcpss XMM4, XMM4
                shufps XMM4, XMM4, 0;

                align 8;
            startsseloopa:
                movaps XMM0, [ESI];
                movaps XMM1, [ESI+16];
                movaps XMM2, [ESI+32];
                movaps XMM3, [ESI+48];
                add ESI, 64;
                mulps XMM0, XMM4;
                mulps XMM1, XMM4;
                mulps XMM2, XMM4;
                mulps XMM3, XMM4;
                //divps XMM0, XMM4;
                //divps XMM1, XMM4;
                //divps XMM2, XMM4;
                //divps XMM3, XMM4;
                movaps [ESI+ 0-64], XMM0;
                movaps [ESI+16-64], XMM1;
                movaps [ESI+32-64], XMM2;
                movaps [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopa;

                mov aptr, ESI;
            }
        }
        else
        // 3DNow! version is 57% faster
        if (amd3dnow() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            T[2] w = void;

            w[0] = w[1] = recip;

            asm
            {
                mov ESI, dword ptr [aptr];
                mov EDI, dword ptr [n];
                movq MM4, qword ptr [w];

                align 8;
            start:
                movq MM0, [ESI];
                movq MM1, [ESI+8];
                movq MM2, [ESI+16];
                movq MM3, [ESI+24];
                pfmul MM0, MM4;
                pfmul MM1, MM4;
                pfmul MM2, MM4;
                pfmul MM3, MM4;
                movq [ESI], MM0;
                movq [ESI+8], MM1;
                movq [ESI+16], MM2;
                movq [ESI+24], MM3;
                add ESI, 32;
                cmp ESI, EDI;
                jb start;

                emms;
                mov dword ptr [aptr], ESI;
            }
        }
    }

    while (aptr < aend)
        *aptr++ *= recip;

    return a;
}

unittest
{
    printf("_arrayExpSliceDivass_f unittest\n");
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
            c[] /= 8;

            for (int i = 0; i < dim; i++)
            {
                if (c[i] != cast(T)(a[i] / 8))
                {
                    printf("[%d]: %g != %g / 8\n", i, c[i], a[i]);
                    assert(0);
                }
            }
        }
    }
}


/* ======================================================================== */

/***********************
 * Computes:
 *      a[] -= b[] * value
 */

T[] _arraySliceExpMulSliceMinass_f(T[] a, T value, T[] b)
{
    return _arraySliceExpMulSliceAddass_f(a, -value, b);
}

/***********************
 * Computes:
 *      a[] += b[] * value
 */

T[] _arraySliceExpMulSliceAddass_f(T[] a, T value, T[] b)
in
{
        assert(a.length == b.length);
        assert(disjoint(a, b));
}
body
{
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    // Handle remainder
    while (aptr < aend)
        *aptr++ += *bptr++ * value;

    return a;
}

unittest
{
    printf("_arraySliceExpMulSliceAddass_f unittest\n");

    cpuid = 1;
    {
        version (log) printf("    cpuid %d\n", cpuid);

        for (int j = 0; j < 1; j++)
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
            c[] += a[] * 6;

            for (int i = 0; i < dim; i++)
            {
                //printf("[%d]: %g ?= %g + %g * 6\n", i, c[i], b[i], a[i]);
                if (c[i] != cast(T)(b[i] + a[i] * 6))
                {
                    printf("[%d]: %g ?= %g + %g * 6\n", i, c[i], b[i], a[i]);
                    assert(0);
                }
            }
        }
    }
}
