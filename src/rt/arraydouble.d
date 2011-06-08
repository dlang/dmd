/**
 * Contains SSE2 and MMX versions of certain operations for double.
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
module rt.arraydouble;

// debug=PRINTF

private import core.cpuid;

version (unittest)
{
    private import core.stdc.stdio : printf;
    /* This is so unit tests will test every CPU variant
     */
    int cpuid;
    const int CPUID_MAX = 5;
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

/* Performance figures measured by Burton Radons
 */

alias double T;

extern (C):

/* ======================================================================== */

/***********************
 * Computes:
 *      a[] = b[] + c[]
 */

T[] _arraySliceSliceAddSliceAssign_d(T[] a, T[] c, T[] b)
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
        // SSE2 version is 333% faster
        if (sse2() && b.length >= 16)
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
                movupd XMM0, [EAX];
                movupd XMM1, [EAX+16];
                movupd XMM2, [EAX+32];
                movupd XMM3, [EAX+48];
                add EAX, 64;
                movupd XMM4, [ECX];
                movupd XMM5, [ECX+16];
                movupd XMM6, [ECX+32];
                movupd XMM7, [ECX+48];
                add ESI, 64;
                addpd XMM0, XMM4;
                addpd XMM1, XMM5;
                addpd XMM2, XMM6;
                addpd XMM3, XMM7;
                add ECX, 64;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopb;

                mov aptr, ESI;
                mov bptr, EAX;
                mov cptr, ECX;
            }
        }
    }

    // Handle remainder
    while (aptr < aend)
        *aptr++ = *bptr++ + *cptr++;

    return a;
}


unittest
{
    debug(PRINTF) printf("_arraySliceSliceAddSliceAssign_d unittest\n");
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

T[] _arraySliceSliceMinSliceAssign_d(T[] a, T[] c, T[] b)
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
        // SSE2 version is 324% faster
        if (sse2() && b.length >= 8)
        {
            auto n = aptr + (b.length & ~7);

            // Unaligned case
            asm
            {
                mov EAX, bptr; // left operand
                mov ECX, cptr; // right operand
                mov ESI, aptr; // destination operand
                mov EDI, n;    // end comparison

                align 8;
            startsseloopb:
                movupd XMM0, [EAX];
                movupd XMM1, [EAX+16];
                movupd XMM2, [EAX+32];
                movupd XMM3, [EAX+48];
                add EAX, 64;
                movupd XMM4, [ECX];
                movupd XMM5, [ECX+16];
                movupd XMM6, [ECX+32];
                movupd XMM7, [ECX+48];
                add ESI, 64;
                subpd XMM0, XMM4;
                subpd XMM1, XMM5;
                subpd XMM2, XMM6;
                subpd XMM3, XMM7;
                add ECX, 64;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopb;

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
    debug(PRINTF) printf("_arraySliceSliceMinSliceAssign_d unittest\n");
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
                    printf("[%d]: %g != %g - %g\n", i, c[i], a[i], b[i]);
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

T[] _arraySliceExpAddSliceAssign_d(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpAddSliceAssign_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 305% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            // Unaligned case
            asm
            {
                mov EAX, bptr;
                mov ESI, aptr;
                mov EDI, n;
                movsd XMM4, value;
                shufpd XMM4, XMM4, 0;

                align 8;
            startsseloop:
                add ESI, 64;
                movupd XMM0, [EAX];
                movupd XMM1, [EAX+16];
                movupd XMM2, [EAX+32];
                movupd XMM3, [EAX+48];
                add EAX, 64;
                addpd XMM0, XMM4;
                addpd XMM1, XMM4;
                addpd XMM2, XMM4;
                addpd XMM3, XMM4;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloop;

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
    debug(PRINTF) printf("_arraySliceExpAddSliceAssign_d unittest\n");
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

T[] _arrayExpSliceAddass_d(T[] a, T value)
{
    //printf("_arrayExpSliceAddass_d(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 114% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);
            if (aptr < n)

            // Unaligned case
            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movsd XMM4, value;
                shufpd XMM4, XMM4, 0;

                align 8;
            startsseloopa:
                movupd XMM0, [ESI];
                movupd XMM1, [ESI+16];
                movupd XMM2, [ESI+32];
                movupd XMM3, [ESI+48];
                add ESI, 64;
                addpd XMM0, XMM4;
                addpd XMM1, XMM4;
                addpd XMM2, XMM4;
                addpd XMM3, XMM4;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopa;

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
    debug(PRINTF) printf("_arrayExpSliceAddass_d unittest\n");
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

T[] _arraySliceSliceAddass_d(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceAddass_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 183% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            // Unaligned case
            asm
            {
                mov ECX, bptr; // right operand
                mov ESI, aptr; // destination operand
                mov EDI, n; // end comparison

                align 8;
            startsseloopb:
                movupd XMM0, [ESI];
                movupd XMM1, [ESI+16];
                movupd XMM2, [ESI+32];
                movupd XMM3, [ESI+48];
                add ESI, 64;
                movupd XMM4, [ECX];
                movupd XMM5, [ECX+16];
                movupd XMM6, [ECX+32];
                movupd XMM7, [ECX+48];
                add ECX, 64;
                addpd XMM0, XMM4;
                addpd XMM1, XMM5;
                addpd XMM2, XMM6;
                addpd XMM3, XMM7;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopb;

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
    debug(PRINTF) printf("_arraySliceSliceAddass_d unittest\n");
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

T[] _arraySliceExpMinSliceAssign_d(T[] a, T value, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceExpMinSliceAssign_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 305% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            // Unaligned case
            asm
            {
                mov EAX, bptr;
                mov ESI, aptr;
                mov EDI, n;
                movsd XMM4, value;
                shufpd XMM4, XMM4, 0;

                align 8;
            startsseloop:
                add ESI, 64;
                movupd XMM0, [EAX];
                movupd XMM1, [EAX+16];
                movupd XMM2, [EAX+32];
                movupd XMM3, [EAX+48];
                add EAX, 64;
                subpd XMM0, XMM4;
                subpd XMM1, XMM4;
                subpd XMM2, XMM4;
                subpd XMM3, XMM4;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloop;

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
    debug(PRINTF) printf("_arraySliceExpMinSliceAssign_d unittest\n");
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

T[] _arrayExpSliceMinSliceAssign_d(T[] a, T[] b, T value)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arrayExpSliceMinSliceAssign_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 66% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            // Unaligned case
            asm
            {
                mov EAX, bptr;
                mov ESI, aptr;
                mov EDI, n;
                movsd XMM4, value;
                shufpd XMM4, XMM4, 0;

                align 8;
            startsseloop:
                add ESI, 64;
                movapd XMM5, XMM4;
                movapd XMM6, XMM4;
                movupd XMM0, [EAX];
                movupd XMM1, [EAX+16];
                movupd XMM2, [EAX+32];
                movupd XMM3, [EAX+48];
                add EAX, 64;
                subpd XMM5, XMM0;
                subpd XMM6, XMM1;
                movupd [ESI+ 0-64], XMM5;
                movupd [ESI+16-64], XMM6;
                movapd XMM5, XMM4;
                movapd XMM6, XMM4;
                subpd XMM5, XMM2;
                subpd XMM6, XMM3;
                movupd [ESI+32-64], XMM5;
                movupd [ESI+48-64], XMM6;
                cmp ESI, EDI;
                jb startsseloop;

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
    debug(PRINTF) printf("_arrayExpSliceMinSliceAssign_d unittest\n");
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

T[] _arrayExpSliceMinass_d(T[] a, T value)
{
    //printf("_arrayExpSliceMinass_d(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 115% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);
            if (aptr < n)

            // Unaligned case
            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movsd XMM4, value;
                shufpd XMM4, XMM4, 0;

                align 8;
            startsseloopa:
                movupd XMM0, [ESI];
                movupd XMM1, [ESI+16];
                movupd XMM2, [ESI+32];
                movupd XMM3, [ESI+48];
                add ESI, 64;
                subpd XMM0, XMM4;
                subpd XMM1, XMM4;
                subpd XMM2, XMM4;
                subpd XMM3, XMM4;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopa;

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
    debug(PRINTF) printf("_arrayExpSliceMinass_d unittest\n");
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

T[] _arraySliceSliceMinass_d(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceMinass_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 183% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            // Unaligned case
            asm
            {
                mov ECX, bptr; // right operand
                mov ESI, aptr; // destination operand
                mov EDI, n; // end comparison

                align 8;
            startsseloopb:
                movupd XMM0, [ESI];
                movupd XMM1, [ESI+16];
                movupd XMM2, [ESI+32];
                movupd XMM3, [ESI+48];
                add ESI, 64;
                movupd XMM4, [ECX];
                movupd XMM5, [ECX+16];
                movupd XMM6, [ECX+32];
                movupd XMM7, [ECX+48];
                add ECX, 64;
                subpd XMM0, XMM4;
                subpd XMM1, XMM5;
                subpd XMM2, XMM6;
                subpd XMM3, XMM7;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopb;

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
    debug(PRINTF) printf("_arrayExpSliceMinass_d unittest\n");
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

T[] _arraySliceExpMulSliceAssign_d(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpMulSliceAssign_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 304% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            // Unaligned case
            asm
            {
                mov EAX, bptr;
                mov ESI, aptr;
                mov EDI, n;
                movsd XMM4, value;
                shufpd XMM4, XMM4, 0;

                align 8;
            startsseloop:
                add ESI, 64;
                movupd XMM0, [EAX];
                movupd XMM1, [EAX+16];
                movupd XMM2, [EAX+32];
                movupd XMM3, [EAX+48];
                add EAX, 64;
                mulpd XMM0, XMM4;
                mulpd XMM1, XMM4;
                mulpd XMM2, XMM4;
                mulpd XMM3, XMM4;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloop;

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
    debug(PRINTF) printf("_arraySliceExpMulSliceAssign_d unittest\n");
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

T[] _arraySliceSliceMulSliceAssign_d(T[] a, T[] c, T[] b)
in
{
        assert(a.length == b.length && b.length == c.length);
        assert(disjoint(a, b));
        assert(disjoint(a, c));
        assert(disjoint(b, c));
}
body
{
    //printf("_arraySliceSliceMulSliceAssign_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;
    auto cptr = c.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 329% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            // Unaligned case
            asm
            {
                mov EAX, bptr; // left operand
                mov ECX, cptr; // right operand
                mov ESI, aptr; // destination operand
                mov EDI, n; // end comparison

                align 8;
            startsseloopb:
                movupd XMM0, [EAX];
                movupd XMM1, [EAX+16];
                movupd XMM2, [EAX+32];
                movupd XMM3, [EAX+48];
                add ESI, 64;
                movupd XMM4, [ECX];
                movupd XMM5, [ECX+16];
                movupd XMM6, [ECX+32];
                movupd XMM7, [ECX+48];
                add EAX, 64;
                mulpd XMM0, XMM4;
                mulpd XMM1, XMM5;
                mulpd XMM2, XMM6;
                mulpd XMM3, XMM7;
                add ECX, 64;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopb;

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
    debug(PRINTF) printf("_arraySliceSliceMulSliceAssign_d unittest\n");
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

T[] _arrayExpSliceMulass_d(T[] a, T value)
{
    //printf("_arrayExpSliceMulass_d(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 109% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);
            if (aptr < n)

            // Unaligned case
            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movsd XMM4, value;
                shufpd XMM4, XMM4, 0;

                align 8;
            startsseloopa:
                movupd XMM0, [ESI];
                movupd XMM1, [ESI+16];
                movupd XMM2, [ESI+32];
                movupd XMM3, [ESI+48];
                add ESI, 64;
                mulpd XMM0, XMM4;
                mulpd XMM1, XMM4;
                mulpd XMM2, XMM4;
                mulpd XMM3, XMM4;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopa;

                mov aptr, ESI;
            }
        }
    }

    while (aptr < aend)
        *aptr++ *= value;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arrayExpSliceMulass_d unittest\n");
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

T[] _arraySliceSliceMulass_d(T[] a, T[] b)
in
{
    assert (a.length == b.length);
    assert (disjoint(a, b));
}
body
{
    //printf("_arraySliceSliceMulass_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 205% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            // Unaligned case
            asm
            {
                mov ECX, bptr; // right operand
                mov ESI, aptr; // destination operand
                mov EDI, n; // end comparison

                align 8;
            startsseloopb:
                movupd XMM0, [ESI];
                movupd XMM1, [ESI+16];
                movupd XMM2, [ESI+32];
                movupd XMM3, [ESI+48];
                add ESI, 64;
                movupd XMM4, [ECX];
                movupd XMM5, [ECX+16];
                movupd XMM6, [ECX+32];
                movupd XMM7, [ECX+48];
                add ECX, 64;
                mulpd XMM0, XMM4;
                mulpd XMM1, XMM5;
                mulpd XMM2, XMM6;
                mulpd XMM3, XMM7;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopb;

                mov aptr, ESI;
                mov bptr, ECX;
            }
        }
    }

    while (aptr < aend)
        *aptr++ *= *bptr++;

    return a;
}

unittest
{
    debug(PRINTF) printf("_arrayExpSliceMulass_d unittest\n");
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

T[] _arraySliceExpDivSliceAssign_d(T[] a, T value, T[] b)
in
{
    assert(a.length == b.length);
    assert(disjoint(a, b));
}
body
{
    //printf("_arraySliceExpDivSliceAssign_d()\n");
    auto aptr = a.ptr;
    auto aend = aptr + a.length;
    auto bptr = b.ptr;

    /* Multiplying by the reciprocal is faster, but does
     * not produce as accurate an answer.
     */
    T recip = cast(T)1 / value;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 299% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            // Unaligned case
            asm
            {
                mov EAX, bptr;
                mov ESI, aptr;
                mov EDI, n;
                movsd XMM4, recip;
                //movsd XMM4, value
                //rcpsd XMM4, XMM4
                shufpd XMM4, XMM4, 0;

                align 8;
            startsseloop:
                add ESI, 64;
                movupd XMM0, [EAX];
                movupd XMM1, [EAX+16];
                movupd XMM2, [EAX+32];
                movupd XMM3, [EAX+48];
                add EAX, 64;
                mulpd XMM0, XMM4;
                mulpd XMM1, XMM4;
                mulpd XMM2, XMM4;
                mulpd XMM3, XMM4;
                //divpd XMM0, XMM4;
                //divpd XMM1, XMM4;
                //divpd XMM2, XMM4;
                //divpd XMM3, XMM4;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloop;

                mov aptr, ESI;
                mov bptr, EAX;
            }
        }
    }

    while (aptr < aend)
    {
        *aptr++ = *bptr++ / value;
        //*aptr++ = *bptr++ * recip;
    }

    return a;
}

unittest
{
    debug(PRINTF) printf("_arraySliceExpDivSliceAssign_d unittest\n");
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
                //printf("[%d]: %g ?= %g / 8\n", i, c[i], a[i]);
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

T[] _arrayExpSliceDivass_d(T[] a, T value)
{
    //printf("_arrayExpSliceDivass_d(a.length = %d, value = %Lg)\n", a.length, cast(real)value);
    auto aptr = a.ptr;
    auto aend = aptr + a.length;

    /* Multiplying by the reciprocal is faster, but does
     * not produce as accurate an answer.
     */
    T recip = cast(T)1 / value;

    version (D_InlineAsm_X86)
    {
        // SSE2 version is 65% faster
        if (sse2() && a.length >= 8)
        {
            auto n = aptr + (a.length & ~7);

            // Unaligned case
            asm
            {
                mov ESI, aptr;
                mov EDI, n;
                movsd XMM4, recip;
                //movsd XMM4, value
                //rcpsd XMM4, XMM4
                shufpd XMM4, XMM4, 0;

                align 8;
            startsseloopa:
                movupd XMM0, [ESI];
                movupd XMM1, [ESI+16];
                movupd XMM2, [ESI+32];
                movupd XMM3, [ESI+48];
                add ESI, 64;
                mulpd XMM0, XMM4;
                mulpd XMM1, XMM4;
                mulpd XMM2, XMM4;
                mulpd XMM3, XMM4;
                //divpd XMM0, XMM4;
                //divpd XMM1, XMM4;
                //divpd XMM2, XMM4;
                //divpd XMM3, XMM4;
                movupd [ESI+ 0-64], XMM0;
                movupd [ESI+16-64], XMM1;
                movupd [ESI+32-64], XMM2;
                movupd [ESI+48-64], XMM3;
                cmp ESI, EDI;
                jb startsseloopa;

                mov aptr, ESI;
            }
        }
    }

    while (aptr < aend)
        *aptr++ *= recip;

    return a;
}


unittest
{
    debug(PRINTF) printf("_arrayExpSliceDivass_d unittest\n");
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

T[] _arraySliceExpMulSliceMinass_d(T[] a, T value, T[] b)
{
    return _arraySliceExpMulSliceAddass_d(a, -value, b);
}

/***********************
 * Computes:
 *      a[] += b[] * value
 */

T[] _arraySliceExpMulSliceAddass_d(T[] a, T value, T[] b)
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
    debug(PRINTF) printf("_arraySliceExpMulSliceAddass_d unittest\n");

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
