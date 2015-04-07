
// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.intrange;

import core.stdc.stdio;

import ddmd.mtype;
import ddmd.expression;
import ddmd.globals;

enum UINT64_MAX = 0xFFFFFFFFFFFFFFFFUL;

static uinteger_t copySign(uinteger_t x, bool sign)
{
    // return sign ? -x : x;
    return (x - cast(uinteger_t)sign) ^ -cast(uinteger_t)sign;
}

struct SignExtendedNumber
{
    ulong value;
    bool negative;
    static SignExtendedNumber fromInteger(uinteger_t value_)
    {
        return SignExtendedNumber(value_, value_ >> 63);
    }

    static SignExtendedNumber extreme(bool minimum)
    {
        return SignExtendedNumber(minimum - 1, minimum);
    }

    static SignExtendedNumber max()
    {
        return SignExtendedNumber(UINT64_MAX, false);
    }

    static SignExtendedNumber min()
    {
        return SignExtendedNumber(0, true);
    }

    bool isMinimum() const
    {
        return negative && value == 0;
    }

    bool opEquals(const ref SignExtendedNumber a) const
    {
        return value == a.value && negative == a.negative;
    }

    int opCmp(const ref SignExtendedNumber a) const
    {
        if (negative != a.negative)
        {
            if (negative)
                return -1;
            else
                return 1;
        }
        if (value < a.value)
            return -1;
        else if (value > a.value)
            return 1;
        else
            return 0;
    }

    SignExtendedNumber opNeg() const
    {
        if (value == 0)
            return SignExtendedNumber(-cast(ulong)negative);
        else
            return SignExtendedNumber(-value, !negative);
    }

    SignExtendedNumber opAdd(const SignExtendedNumber a) const
    {
        uinteger_t sum = value + a.value;
        bool carry = sum < value && sum < a.value;
        if (negative != a.negative)
            return SignExtendedNumber(sum, !carry);
        else if (negative)
            return SignExtendedNumber(carry ? sum : 0, true);
        else
            return SignExtendedNumber(carry ? UINT64_MAX : sum, false);
    }

    SignExtendedNumber opSub(const SignExtendedNumber a) const
    {
        if (a.isMinimum())
            return negative ? SignExtendedNumber(value, false) : max();
        else
            return this + (-a);
    }

    SignExtendedNumber opMul(const SignExtendedNumber a) const
    {
        // perform *saturated* multiplication, otherwise we may get bogus ranges
        //  like 0x10 * 0x10 == 0x100 == 0.

        /* Special handling for zeros:
            INT65_MIN * 0 = 0
            INT65_MIN * + = INT65_MIN
            INT65_MIN * - = INT65_MAX
            0 * anything = 0
        */
        if (value == 0)
        {
            if (!negative)
                return this;
            else if (a.negative)
                return max();
            else
                return a.value == 0 ? a : this;
        }
        else if (a.value == 0)
            return a * this; // don't duplicate the symmetric case.

        SignExtendedNumber rv;
        // these are != 0 now surely.
        uinteger_t tAbs = copySign(value, negative);
        uinteger_t aAbs = copySign(a.value, a.negative);
        rv.negative = negative != a.negative;
        if (UINT64_MAX / tAbs < aAbs)
            rv.value = rv.negative - 1;
        else
            rv.value = copySign(tAbs * aAbs, rv.negative);
        return rv;
    }

    SignExtendedNumber opDiv(const SignExtendedNumber a) const
    {
        /* special handling for zeros:
            INT65_MIN / INT65_MIN = 1
            anything / INT65_MIN = 0
            + / 0 = INT65_MAX  (eh?)
            - / 0 = INT65_MIN  (eh?)
        */
        if (a.value == 0)
        {
            if (a.negative)
                return SignExtendedNumber(value == 0 && negative);
            else
                return extreme(negative);
        }

        uinteger_t aAbs = copySign(a.value, a.negative);
        uinteger_t rvVal;

        if (!isMinimum())
            rvVal = copySign(value, negative) / aAbs;
        // Special handling for INT65_MIN
        //  if the denominator is not a power of 2, it is same as UINT64_MAX / x.
        else if (aAbs & (aAbs - 1))
            rvVal = UINT64_MAX / aAbs;
        // otherwise, it's the same as reversing the bits of x.
        else
        {
            if (aAbs == 1)
                return extreme(!a.negative);
            rvVal = 1UL << 63;
            aAbs >>= 1;
            if (aAbs & 0xAAAAAAAAAAAAAAAAUL) rvVal >>= 1;
            if (aAbs & 0xCCCCCCCCCCCCCCCCUL) rvVal >>= 2;
            if (aAbs & 0xF0F0F0F0F0F0F0F0UL) rvVal >>= 4;
            if (aAbs & 0xFF00FF00FF00FF00UL) rvVal >>= 8;
            if (aAbs & 0xFFFF0000FFFF0000UL) rvVal >>= 16;
            if (aAbs & 0xFFFFFFFF00000000UL) rvVal >>= 32;
        }
        bool rvNeg = negative != a.negative;
        rvVal = copySign(rvVal, rvNeg);

        return SignExtendedNumber(rvVal, rvVal != 0 && rvNeg);
    }

    SignExtendedNumber opMod(const SignExtendedNumber a) const
    {
        if (a.value == 0)
            return !a.negative ? a : isMinimum() ? SignExtendedNumber(0) : this;

        uinteger_t aAbs = copySign(a.value, a.negative);
        uinteger_t rvVal;

        // a % b == sgn(a) * abs(a) % abs(b).
        if (!isMinimum())
            rvVal = copySign(value, negative) % aAbs;
        // Special handling for INT65_MIN
        //  if the denominator is not a power of 2, it is same as UINT64_MAX%x + 1.
        else if (aAbs & (aAbs - 1))
            rvVal = UINT64_MAX % aAbs + 1;
        //  otherwise, the modulus is trivially zero.
        else
            rvVal = 0;

        rvVal = copySign(rvVal, negative);
        return SignExtendedNumber(rvVal, rvVal != 0 && negative);
    }

    ref SignExtendedNumber opAddAssign(int a)
    {
        assert(a == 1);
        if (value != UINT64_MAX)
            ++value;
        else if (negative)
        {
            value = 0;
            negative = false;
        }
        return this;
    }

    SignExtendedNumber opShl(const SignExtendedNumber a)
    {
        // assume left-shift the shift-amount is always unsigned. Thus negative
        //  shifts will give huge result.
        if (value == 0)
            return this;
        else if (a.negative)
            return extreme(negative);

        uinteger_t v = copySign(value, negative);

        // compute base-2 log of 'v' to determine the maximum allowed bits to shift.
        // Ref: http://graphics.stanford.edu/~seander/bithacks.html#IntegerLog

        // Why is this a size_t? Looks like a bug.
        size_t r, s;

        r = (v > 0xFFFFFFFFUL) << 5; v >>= r;
        s = (v > 0xFFFFUL    ) << 4; v >>= s; r |= s;
        s = (v > 0xFFUL      ) << 3; v >>= s; r |= s;
        s = (v > 0xFUL       ) << 2; v >>= s; r |= s;
        s = (v > 0x3UL       ) << 1; v >>= s; r |= s;
                                               r |= (v >> 1);

        uinteger_t allowableShift = 63 - r;
        if (a.value > allowableShift)
            return extreme(negative);
        else
            return SignExtendedNumber(value << a.value, negative);
    }

    SignExtendedNumber opShr(const SignExtendedNumber a)
    {
        if (a.negative || a.value > 64)
            return negative ? SignExtendedNumber(-1, true) : SignExtendedNumber(0);
        else if (isMinimum())
            return a.value == 0 ? this : SignExtendedNumber(-1UL << (64 - a.value), true);

        uinteger_t x = value ^ -cast(int)negative;
        x >>= a.value;
        return SignExtendedNumber(x ^ -cast(int)negative, negative);
    }
}

struct IntRange
{
    SignExtendedNumber imin, imax;

    this(SignExtendedNumber a)
    {
        imin = a;
        imax = a;
    }

    this(SignExtendedNumber lower, SignExtendedNumber upper)
    {
        imin = lower;
        imax = upper;
    }

    static IntRange fromType(Type type)
    {
        return fromType(type, type.isunsigned());
    }

    static IntRange fromType(Type type, bool isUnsigned)
    {
        if (!type.isintegral())
            return widest();

        uinteger_t mask = type.sizemask();
        auto lower = SignExtendedNumber(0);
        auto upper = SignExtendedNumber(mask);
        if (type.toBasetype().ty == Tdchar)
            upper.value = 0x10FFFFUL;
        else if (!isUnsigned)
        {
            lower.value = ~(mask >> 1);
            lower.negative = true;
            upper.value = (mask >> 1);
        }
        return IntRange(lower, upper);
    }

    static IntRange fromNumbers2(SignExtendedNumber* numbers)
    {
        if (numbers[0] < numbers[1])
            return IntRange(numbers[0], numbers[1]);
        else
            return IntRange(numbers[1], numbers[0]);
    }

    static IntRange fromNumbers4(SignExtendedNumber* numbers)
    {
        IntRange ab = fromNumbers2(numbers);
        IntRange cd = fromNumbers2(numbers + 2);
        if (cd.imin < ab.imin)
            ab.imin = cd.imin;
        if (cd.imax > ab.imax)
            ab.imax = cd.imax;
        return ab;
    }

    static IntRange widest()
    {
        return IntRange(SignExtendedNumber.min(), SignExtendedNumber.max());
    }

    IntRange castSigned(uinteger_t mask)
    {
        // .... 0x1e7f ] [0x1e80 .. 0x1f7f] [0x1f80 .. 0x7f] [0x80 .. 0x17f] [0x180 ....
        //
        // regular signed type. We use a technique similar to the unsigned version,
        //  but the chunk has to be offset by 1/2 of the range.
        uinteger_t halfChunkMask = mask >> 1;
        uinteger_t minHalfChunk = imin.value & ~halfChunkMask;
        uinteger_t maxHalfChunk = imax.value & ~halfChunkMask;
        int minHalfChunkNegativity = imin.negative; // 1 = neg, 0 = nonneg, -1 = chunk containing ::max
        int maxHalfChunkNegativity = imax.negative;
        if (minHalfChunk & mask)
        {
            minHalfChunk += halfChunkMask + 1;
            if (minHalfChunk == 0)
                --minHalfChunkNegativity;
        }
        if (maxHalfChunk & mask)
        {
            maxHalfChunk += halfChunkMask + 1;
            if (maxHalfChunk == 0)
                --maxHalfChunkNegativity;
        }
        if (minHalfChunk == maxHalfChunk && minHalfChunkNegativity == maxHalfChunkNegativity)
        {
            imin.value &= mask;
            imax.value &= mask;
            // sign extend if necessary.
            imin.negative = (imin.value & ~halfChunkMask) != 0;
            imax.negative = (imax.value & ~halfChunkMask) != 0;
            halfChunkMask += 1;
            imin.value = (imin.value ^ halfChunkMask) - halfChunkMask;
            imax.value = (imax.value ^ halfChunkMask) - halfChunkMask;
        }
        else
        {
            imin = SignExtendedNumber(~halfChunkMask, true);
            imax = SignExtendedNumber(halfChunkMask, false);
        }
        return this;
    }

    IntRange castUnsigned(uinteger_t mask)
    {
        // .... 0x1eff ] [0x1f00 .. 0x1fff] [0 .. 0xff] [0x100 .. 0x1ff] [0x200 ....
        //
        // regular unsigned type. We just need to see if ir steps across the
        //  boundary of validRange. If yes, ir will represent the whole validRange,
        //  otherwise, we just take the modulus.
        // e.g. [0x105, 0x107] & 0xff == [5, 7]
        //      [0x105, 0x207] & 0xff == [0, 0xff]
        uinteger_t minChunk = imin.value & ~mask;
        uinteger_t maxChunk = imax.value & ~mask;
        if (minChunk == maxChunk && imin.negative == imax.negative)
        {
            imin.value &= mask;
            imax.value &= mask;
        }
        else
        {
            imin.value = 0;
            imax.value = mask;
        }
        imin.negative = imax.negative = false;
        return this;
    }

    IntRange castDchar()
    {
        // special case for dchar. Casting to dchar means "I'll ignore all
        //  invalid characters."
        castUnsigned(0xFFFFFFFFUL);
        if (imin.value > 0x10FFFFUL) // ??
            imin.value = 0x10FFFFUL; // ??
        if (imax.value > 0x10FFFFUL)
            imax.value = 0x10FFFFUL;
        return this;
    }

    IntRange _cast(Type type)
    {
        if (!type.isintegral())
            return this;
        else if (!type.isunsigned())
            return castSigned(type.sizemask());
        else if (type.toBasetype().ty == Tdchar)
            return castDchar();
        else
            return castUnsigned(type.sizemask());
    }

    IntRange castUnsigned(Type type)
    {
        if (!type.isintegral())
            return castUnsigned(UINT64_MAX);
        else if (type.toBasetype().ty == Tdchar)
            return castDchar();
        else
            return castUnsigned(type.sizemask());
    }

    bool contains(IntRange a)
    {
        return imin <= a.imin && imax >= a.imax;
    }

    bool containsZero() const
    {
        return (imin.negative && !imax.negative)
            || (!imin.negative && imin.value == 0);
    }

    IntRange absNeg() const
    {
        if (imax.negative)
            return this;
        else if (!imin.negative)
            return IntRange(-imax, -imin);
        else
        {
            SignExtendedNumber imaxAbsNeg = -imax;
            return IntRange(imaxAbsNeg < imin ? imaxAbsNeg : imin,
                            SignExtendedNumber(0));
        }
    }

    IntRange unionWith(const ref IntRange other) const
    {
        return IntRange(imin < other.imin ? imin : other.imin,
                        imax > other.imax ? imax : other.imax);
    }

    void unionOrAssign(IntRange other, ref bool union_)
    {
        if (!union_ || imin > other.imin)
            imin = other.imin;
        if (!union_ || imax < other.imax)
            imax = other.imax;
        union_ = true;
    }

    ref const(IntRange) dump(const(char)* funcName, Expression e) const
    {
        printf("[(%c)%#018llx, (%c)%#018llx] @ %s ::: %s\n",
               imin.negative?'-':'+', cast(ulong)imin.value,
               imax.negative?'-':'+', cast(ulong)imax.value,
               funcName, e.toChars());
        return this;
    }

    void splitBySign(ref IntRange negRange, ref bool hasNegRange, ref IntRange nonNegRange, ref bool hasNonNegRange) const
    {
        hasNegRange = imin.negative;
        if (hasNegRange)
        {
            negRange.imin = imin;
            negRange.imax = imax.negative ? imax : SignExtendedNumber(-1, true);
        }
        hasNonNegRange = !imax.negative;
        if (hasNonNegRange)
        {
            nonNegRange.imin = imin.negative ? SignExtendedNumber(0) : imin;
            nonNegRange.imax = imax;
        }
    }
}
