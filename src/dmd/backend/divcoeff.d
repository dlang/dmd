/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2013-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/divcoeff.d, backend/divcoeff.d)
 */

/***************************************************
 * Algorithms from "Division by Invariant Integers using Multiplication"
 * by Torbjoern Granlund and Peter L. Montgomery
 */

import core.stdc.stdio;

extern (C++):

nothrow:
@safe:

import core.stdc.stdint : uint64_t;
alias ullong = uint64_t;

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

void u128Div(ullong xh, ullong xl, ullong yh, ullong yl, ullong *pqh, ullong *pql)
{
    /* Use auld skool shift & subtract algorithm.
     * Not very efficient.
     */

    //ullong xxh = xh, xxl = xl, yyh = yh, yyl = yl;

    assert(yh || yl);           // no div-by-0 bugs

    // left justify y
    uint shiftcount = 1;
    if (!yh)
    {   yh = yl;
        yl = 0;
        shiftcount += 64;
    }
    while (!SIGN64(yh))
    {
        SHL128(yh,yl, yh,yl);
        shiftcount += 1;
    }

    ullong qh = 0;
    ullong ql = 0;
    do
    {
        SHL128(qh,ql, qh,ql);
        if (XltY128(yh,yl,xh,xl))
        {
            // x -= y;
            if (xl < yl)
            {   xl -= yl;
                xh -= yh + 1;
            }
            else
            {   xl -= yl;
                xh -= yh;
            }

            ql |= 1;
        }
        SHR128(yh,yl, yh,yl);
    } while (--shiftcount);

    *pqh = qh;
    *pql = ql;

    // Remainder is xh,xl

    version (none)
    {
        printf("%016llx_%016llx / %016llx_%016llx = %016llx_%016llx\n", xxh,xxl,yyh,yyl,qh,ql);
        if (xxh == 0 && yyh == 0)
            printf("should be %llx\n", xxl / yyl);
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
extern (C) bool choose_multiplier(int N, ullong d, int prec, ullong *pm, int *pshpost)
{
    assert(N == 32 || N == 64);
    assert(prec <= N);
    assert(d > 1 && (d & (d - 1)));

    // Compute b such that 2**(b-1) < d <= 2**b
    // which is the number of significant bits in d
    int b = 0;
    ullong d1 = d;
    while (d1)
    {
        ++b;
        d1 >>= 1;
    }

    int shpost = b;

    bool mhighbit = false;
    if (N == 32)
    {
        // mlow = (2**(N + b)) / d
        ullong mlow = (1UL << (N + b)) / d;

        // uhigh = (2**(N + b) + 2**(N + b - prec)) / d
        ullong mhigh = ((1UL << (N + b)) + (1UL << (N + b - prec))) / d;

        while (mlow/2 < mhigh/2 && shpost)
        {
            mlow /= 2;
            mhigh /= 2;
            --shpost;
        }

        *pm = mhigh & 0xFFFFFFFF;
        mhighbit = (mhigh >> N) != 0;
    }
    else if (N == 64)
    {
        // Same as for N==32, but use 128 bit unsigned arithmetic

        // mlow = (2**(N + b)) / d
        ullong mlowl = 0;
        ullong mlowh = 1UL << b;

        // mlow /= d
        u128Div(mlowh, mlowl, 0, d, &mlowh, &mlowl);

        // mhigh = (2**(N + b) + 2**(N + b - prec)) / d
        ullong mhighl = 0;
        ullong mhighh = 1UL << b;
        int e = N + b - prec;
        if (e < 64)
            mhighl = 1UL << e;
        else
            mhighh |= 1UL << (e - 64);

        // mhigh /= d
        u128Div(mhighh, mhighl, 0, d, &mhighh, &mhighl);

        while (1)
        {
            // mlowb = mlow / 2
            ullong mlowbh,mlowbl;
            SHR128(mlowbh,mlowbl, mlowh,mlowl);

            // mhighb = mhigh / 2
            ullong mhighbh,mhighbl;
            SHR128(mhighbh,mhighbl, mhighh,mhighl);

            // if (mlowb < mhighb && shpost)
            if (XltY128(mlowbh,mlowbl, mhighbh,mhighbl) && shpost)
            {
                // mlow = mlowb
                mlowl = mlowbl;
                mlowh = mlowbh;

                // mhigh = mhighb
                mhighl = mhighbl;
                mhighh = mhighbh;

                --shpost;
            }
            else
                break;
        }

        *pm = mhighl;
        mhighbit = mhighh & 1;
    }
    else
        assert(0);

    *pshpost = shpost;
    return mhighbit;
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

extern (C) bool udiv_coefficients(int N, ullong d, int *pshpre, ullong *pm, int *pshpost)
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
}

version (none)
{
    import core.stdc.stdlib;

    extern (D) int main(string[] args)
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
