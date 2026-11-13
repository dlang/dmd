/**
 * Algorithms from "Division by Invariant Integers using Multiplication"
 * by Torbjoern Granlund and Peter L. Montgomery
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2013-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/divcoeff.d, backend/divcoeff.d)
 */
module dmd.backend.divcoeff;

import core.stdc.stdio;


nothrow:
@safe:

alias ullong = ulong;

/* unsigned 128 bit math
 */

bool SIGN64(ullong x)
{
    return cast(long)x < 0;
}

void SHL128(out ullong dh, out ullong dl, ullong xh,ullong xl)
{
    dh = (xh << 1) | SIGN64(xl);
    dl = xl << 1;
}

void SHR128(out ullong dh, out ullong dl, ullong xh,ullong xl)
{
    dl = (xl >> 1) | ((xh & 1) << 63);
    dh = xh >> 1;
}

bool XltY128(ullong xh, ullong xl, ullong yh, ullong yl)
{
    return xh < yh || (xh == yh && xl < yl);
}

/***
 * Compute floor(2^^k / d) and 2^^k % d.
 *
 * 1 <= d <= ulong.max
 * 0 <= k <= 128
 *
 * The quotient is returned as (qh, ql).
 * No intermediate value exceeds 64 bits.
 */
private void divPow2(int k, ullong d,
    out ullong qh, out ullong ql, out ullong rem)
{
    assert(d > 1);
    assert(k >= 0 && k <= 128);
    qh = 0;
    ql = 0;
    rem = 1;
    for (int i = 0; i < k; ++i)
    {
        // Double the 128-bit quotient
        qh = (qh << 1) | (ql >> 63);
        ql <<= 1;
        // Double the remainder, subtracting d
        // if necessary. Avoid overflow of 2*rem
        if (rem >= d - rem)
        {
            rem -= d - rem;
            ++ql;
        }
        else
        {
            rem += rem;
        }
    }
}

/************************************
 * Implement Algorithm 6.2: Selection of multiplier and shift count
 * Params:
 *      N =     32 or 64
 *      d =     divisor (must not be 0 or a power of 2)
 *      prec =  bits of precision desired
 * Output:
 *      *pm =      factor
 *      *pshpost = post shift
 * Returns:
 *      true    m >= 2**N
 */
@trusted
bool choose_multiplier(int N, ullong d, int prec, ullong* pm, int* pshpost)
{
    assert(N == 32 || N == 64);
    assert(prec >= 1 && prec <= N);
    assert(d > 1 && (d & (d - 1)));
    assert(N == 64 || d <= uint.max);

    // Compute b such that 2^^(b-1) < d < 2^^b
    // which is the number of significant bits in d
    int b = 0;
    for (ullong t = d; t; t >>= 1)
        ++b;

    int shpost = b;
    const int k = N + b;
    const int e = k - prec;

    // mlow = floor(2^^k / d)
    ullong mlowh, mlowl, rlow;
    divPow2(k, d, mlowh, mlowl, rlow);

    // Compute floor(2^^e / d) and its remainder
    ullong eh, el, er;
    divPow2(e, d, eh, el, er);

    // mhigh = floor((2^^k + 2^^e) / d)
    //
    //       = floor(2^^k/d)
    //       + floor(2^^e/d)
    //       + carry from the two remainders

    ullong mhighl = mlowl + el;
    ullong carry = cast(ullong)(mhighl < mlowl);
    ullong mhighh = mlowh + eh + carry;

    // Add one if rlow + er >= d
    // Written this way to avoid overflow
    if (rlow >= d - er)
    {
        ++mhighl;
        if (mhighl == 0)
            ++mhighh;
    }

    // Reduce multiplier and post-shift together
    while (shpost)
    {
        ullong lowh, lowl;
        ullong highh, highl;

        SHR128(lowh, lowl, mlowh, mlowl);
        SHR128(highh, highl, mhighh, mhighl);

        if (!XltY128(lowh, lowl, highh, highl))
            break;

        mlowh = lowh;
        mlowl = lowl;
        mhighh = highh;
        mhighl = highl;
        --shpost;
    }

    *pm = N == 32
        ? mhighl & 0xFFFFFFFFUL
        : mhighl;

    *pshpost = shpost;

    return N == 32
        ? ((mhighl >> 32) != 0 || mhighh != 0)
        : (mhighh != 0);
}


/*************************************
 * Find coefficients for Algorithm 4.2:
 * Optimized code generation of unsigned q=n/d for constant nonzero d
 * Input:
 *      N       32 or 64 (width of divide)
 *      d       divisor (not a power of 2)
 * Output:
 *      *pshpre  pre-shift
 *      *pm      factor
 *      *pshpost post-shift
 * Returns:
 *      true    Use algorithm:
 *              t1 = MULUH(m, n)
 *              q = SRL(t1 + SRL(n - t1, 1), shpost - 1)
 *
 *      false   Use algorithm:
 *              q = SRL(MULUH(m, SRL(n, shpre)), shpost)
 */

bool udiv_coefficients(int N, ullong d, int* pshpre, ullong* pm, int* pshpost)
{
    bool mhighbit = choose_multiplier(N, d, N, pm, pshpost);
    if (mhighbit && (d & 1) == 0)
    {
        int e = 0;
        while ((d & 1) == 0)
        {   ++e;
            d >>= 1;
        }
        *pshpre = e;
        mhighbit = choose_multiplier(N, d, N - e, pm, pshpost);
        assert(mhighbit == false);
    }
    else
        *pshpre = 0;
    return mhighbit;
}

@trusted
unittest
{
    struct S
    {
        int N;
        ullong d;
        int shpre;
        int highbit;
        ullong m;
        int shpost;
    }

    static immutable S[14] table =
    [
        { 32, 10,     0, 0, 0xCCCCCCCD, 3 },
        { 32, 13,     0, 0, 0x4EC4EC4F, 2 },
        { 32, 14,     1, 0, 0x92492493, 2 },
        { 32, 15,     0, 0, 0x88888889, 3 },
        { 32, 17,     0, 0, 0xF0F0F0F1, 4 },
        { 32, 14_007, 0, 1, 0x2B71840D, 14 },

        { 64, 7,      0, 1, 0x2492492492492493, 3 },
        { 64, 10,     0, 0, 0xCCCCCCCCCCCCCCCD, 3 },
        { 64, 13,     0, 0, 0x4EC4EC4EC4EC4EC5, 2 },
        { 64, 14,     1, 0, 0x4924924924924925, 1 },
        { 64, 15,     0, 0, 0x8888888888888889, 3 },
        { 64, 17,     0, 0, 0xF0F0F0F0F0F0F0F1, 4 },
        { 64, 100 ,   2, 0, 0x28F5C28F5C28F5C3, 2 },
        { 64, 14_007, 0, 1, 0x2B71840C5ADF02C3, 14 },
    ];

    for (int i = 0; i < table.length; i++)
    {   const ps = &table[i];

        ullong m;
        int shpre;
        int shpost;
        bool mhighbit = udiv_coefficients(ps.N, ps.d, &shpre, &m, &shpost);

        //printf("[%d] %d %d %llx %d\n", i, shpre, mhighbit, m, shpost);
        assert(shpre == ps.shpre);
        assert(mhighbit == ps.highbit);
        assert(m == ps.m);
        assert(shpost == ps.shpost);
    }

    // problematic divisors
    foreach (N; [32, 64])
    {
        const ullong top = 1UL << (N - 1);
        const ullong mask = N == 32 ? 0xFFFFFFFFUL : ulong.max;
        foreach (d; [top + 1, top + 3, mask - 2, mask])
        {
            ullong m;
            int shpre;
            int shpost;
            bool high = udiv_coefficients(N, d, &shpre, &m, &shpost);
            assert(shpre >= 0);
            assert(shpost >= 0);
            assert(shpost <= N);

            // For these odd divisors, no pre-shift
            assert(shpre == 0);
        }
    }
}

version (none)
{
    import core.stdc.stdlib;

    int main(string[] args)
    {
        if (args.length == 2)
        {
            ullong d = atoi(args[1].ptr);
            ullong m;
            int shpre;
            int shpost;
            bool mhighbit = udiv_coefficients(64, d, &shpre, &m, &shpost);

            printf("%d %d %llx, %d\n", shpre, mhighbit, m, shpost);
        }
        return 0;
    }
}
