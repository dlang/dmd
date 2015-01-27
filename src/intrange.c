
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by KennyTM
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/intrange.c
 */

#include "intrange.h"
#include "mars.h"
#include "mtype.h"
#include "expression.h"

#ifndef PERFORM_UNITTEST
#define PERFORM_UNITTEST 0
#endif

// Copy the sign to the value *x*. Equivalent to `sign ? -x : x`.
static uinteger_t copySign(uinteger_t x, bool sign)
{
    // return sign ? -x : x;
    return (x - (uinteger_t)sign) ^ -(uinteger_t)sign;
}

#ifndef UINT64_MAX
#define UINT64_MAX 0xFFFFFFFFFFFFFFFFULL
#endif

//==================== SignExtendedNumber ======================================

SignExtendedNumber SignExtendedNumber::fromInteger(uinteger_t value_)
{
    return SignExtendedNumber(value_, value_ >> 63);
}

bool SignExtendedNumber::operator==(const SignExtendedNumber& a) const
{
    return value == a.value && negative == a.negative;
}

bool SignExtendedNumber::operator<(const SignExtendedNumber& a) const
{
    return (negative && !a.negative)
        || (negative == a.negative && value < a.value);
}

SignExtendedNumber SignExtendedNumber::extreme(bool minimum)
{
    return SignExtendedNumber(minimum-1, minimum);
}

SignExtendedNumber SignExtendedNumber::max()
{
    return SignExtendedNumber(UINT64_MAX, false);
}

SignExtendedNumber SignExtendedNumber::operator-() const
{
    if (value == 0)
        return SignExtendedNumber(-negative);
    else
        return SignExtendedNumber(-value, !negative);
}

SignExtendedNumber SignExtendedNumber::operator+(const SignExtendedNumber& a) const
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

SignExtendedNumber SignExtendedNumber::operator-(const SignExtendedNumber& a) const
{
    if (a.isMinimum())
        return negative ? SignExtendedNumber(value, false) : max();
    else
        return *this + (-a);
}


SignExtendedNumber SignExtendedNumber::operator*(const SignExtendedNumber& a) const
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
            return *this;
        else if (a.negative)
            return max();
        else
            return a.value == 0 ? a : *this;
    }
    else if (a.value == 0)
        return a * *this;   // don't duplicate the symmetric case.

    SignExtendedNumber rv;
    // these are != 0 now surely.
    uinteger_t tAbs = copySign(value, negative);
    uinteger_t aAbs = copySign(a.value, a.negative);
    rv.negative = negative != a.negative;
    if (UINT64_MAX / tAbs < aAbs)
        rv.value = rv.negative-1;
    else
        rv.value = copySign(tAbs * aAbs, rv.negative);
    return rv;
}

SignExtendedNumber SignExtendedNumber::operator/(const SignExtendedNumber& a) const
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
    else if (aAbs & (aAbs-1))
        rvVal = UINT64_MAX / aAbs;
    // otherwise, it's the same as reversing the bits of x.
    else
    {
        if (aAbs == 1)
            return extreme(!a.negative);
        rvVal = 1ULL << 63;
        aAbs >>= 1;
        if (aAbs & 0xAAAAAAAAAAAAAAAAULL) rvVal >>= 1;
        if (aAbs & 0xCCCCCCCCCCCCCCCCULL) rvVal >>= 2;
        if (aAbs & 0xF0F0F0F0F0F0F0F0ULL) rvVal >>= 4;
        if (aAbs & 0xFF00FF00FF00FF00ULL) rvVal >>= 8;
        if (aAbs & 0xFFFF0000FFFF0000ULL) rvVal >>= 16;
        if (aAbs & 0xFFFFFFFF00000000ULL) rvVal >>= 32;
    }
    bool rvNeg = negative != a.negative;
    rvVal = copySign(rvVal, rvNeg);

    return SignExtendedNumber(rvVal, rvVal != 0 && rvNeg);
}

SignExtendedNumber SignExtendedNumber::operator%(const SignExtendedNumber& a) const
{
    if (a.value == 0)
        return !a.negative ? a : isMinimum() ? SignExtendedNumber(0) : *this;

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

SignExtendedNumber& SignExtendedNumber::operator++()
{
    if (value != UINT64_MAX)
        ++ value;
    else if (negative)
    {
        value = 0;
        negative = false;
    }
    return *this;
}

SignExtendedNumber SignExtendedNumber::operator<<(const SignExtendedNumber& a) const
{
    // assume left-shift the shift-amount is always unsigned. Thus negative
    //  shifts will give huge result.
    if (value == 0)
        return *this;
    else if (a.negative)
        return extreme(negative);

    uinteger_t v = copySign(value, negative);

    // compute base-2 log of 'v' to determine the maximum allowed bits to shift.
    // Ref: http://graphics.stanford.edu/~seander/bithacks.html#IntegerLog

    // Why is this a size_t? Looks like a bug.
    size_t r, s;

    r = (v > 0xFFFFFFFFULL) << 5; v >>= r;
    s = (v > 0xFFFFULL    ) << 4; v >>= s; r |= s;
    s = (v > 0xFFULL      ) << 3; v >>= s; r |= s;
    s = (v > 0xFULL       ) << 2; v >>= s; r |= s;
    s = (v > 0x3ULL       ) << 1; v >>= s; r |= s;
                                           r |= (v >> 1);

    uinteger_t allowableShift = 63 - r;
    if (a.value > allowableShift)
        return extreme(negative);
    else
        return SignExtendedNumber(value << a.value, negative);
}

SignExtendedNumber SignExtendedNumber::operator>>(const SignExtendedNumber& a) const
{
    if (a.negative || a.value > 64)
        return negative ? SignExtendedNumber(-1, true) : SignExtendedNumber(0);
    else if (isMinimum())
        return a.value == 0 ? *this : SignExtendedNumber(-1ULL << (64-a.value), true);

    uinteger_t x = value ^ -negative;
    x >>= a.value;
    return SignExtendedNumber(x ^ -negative, negative);
}


//==================== IntRange ================================================

IntRange IntRange::widest()
{
    return IntRange(SignExtendedNumber::min(), SignExtendedNumber::max());
}

#if !PERFORM_UNITTEST
IntRange IntRange::fromType(Type *type)
{
    return fromType(type, type->isunsigned());
}

IntRange IntRange::fromType(Type *type, bool isUnsigned)
{
    if (!type->isintegral())
        return widest();

    uinteger_t mask = type->sizemask();
    SignExtendedNumber lower(0), upper(mask);
    if (type->toBasetype()->ty == Tdchar)
        upper.value = 0x10FFFFULL;
    else if (!isUnsigned)
    {
        lower.value = ~(mask >> 1);
        lower.negative = true;
        upper.value = (mask >> 1);
    }
    return IntRange(lower, upper);
}
#endif

IntRange IntRange::fromNumbers2(const SignExtendedNumber numbers[2])
{
    if (numbers[0] < numbers[1])
        return IntRange(numbers[0], numbers[1]);
    else
        return IntRange(numbers[1], numbers[0]);
}
IntRange IntRange::fromNumbers4(const SignExtendedNumber numbers[4])
{
    IntRange ab = fromNumbers2(numbers);
    IntRange cd = fromNumbers2(numbers + 2);
    if (cd.imin < ab.imin)
        ab.imin = cd.imin;
    if (cd.imax > ab.imax)
        ab.imax = cd.imax;
    return ab;
}

bool IntRange::contains(const IntRange& a) const
{
    return imin <= a.imin && imax >= a.imax;
}

bool IntRange::containsZero() const
{
    return (imin.negative && !imax.negative)
        || (!imin.negative && imin.value == 0);
}

IntRange& IntRange::castUnsigned(uinteger_t mask)
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
    return *this;
}

IntRange& IntRange::castSigned(uinteger_t mask)
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
        minHalfChunk += halfChunkMask+1;
        if (minHalfChunk == 0)
            -- minHalfChunkNegativity;
    }
    if (maxHalfChunk & mask)
    {
        maxHalfChunk += halfChunkMask+1;
        if (maxHalfChunk == 0)
            -- maxHalfChunkNegativity;
    }
    if (minHalfChunk == maxHalfChunk && minHalfChunkNegativity == maxHalfChunkNegativity)
    {
        imin.value &= mask;
        imax.value &= mask;
        // sign extend if necessary.
        imin.negative = imin.value & ~halfChunkMask;
        imax.negative = imax.value & ~halfChunkMask;
        halfChunkMask += 1;
        imin.value = (imin.value ^ halfChunkMask) - halfChunkMask;
        imax.value = (imax.value ^ halfChunkMask) - halfChunkMask;
    }
    else
    {
        imin = SignExtendedNumber(~halfChunkMask, true);
        imax = SignExtendedNumber(halfChunkMask, false);
    }
    return *this;
}

IntRange& IntRange::castDchar()
{
    // special case for dchar. Casting to dchar means "I'll ignore all
    //  invalid characters."
    castUnsigned(0xFFFFFFFFULL);
    if (imin.value > 0x10FFFFULL)   // ??
        imin.value = 0x10FFFFULL;   // ??
    if (imax.value > 0x10FFFFULL)
        imax.value = 0x10FFFFULL;
    return *this;
}

#if !PERFORM_UNITTEST
IntRange& IntRange::cast(Type *type)
{
    if (!type->isintegral())
        return *this;
    else if (!type->isunsigned())
        return castSigned(type->sizemask());
    else if (type->toBasetype()->ty == Tdchar)
        return castDchar();
    else
        return castUnsigned(type->sizemask());
}

IntRange& IntRange::castUnsigned(Type *type)
{
    if (!type->isintegral())
        return castUnsigned(UINT64_MAX);
    else if (type->toBasetype()->ty == Tdchar)
        return castDchar();
    else
        return castUnsigned(type->sizemask());
}
#endif

IntRange IntRange::absNeg() const
{
    if (imax.negative)
        return *this;
    else if (!imin.negative)
        return IntRange(-imax, -imin);
    else
    {
        SignExtendedNumber imaxAbsNeg = -imax;
        return IntRange(imaxAbsNeg < imin ? imaxAbsNeg : imin,
                        SignExtendedNumber(0));
    }
}

IntRange IntRange::unionWith(const IntRange& other) const
{
    return IntRange(imin < other.imin ? imin : other.imin,
                    imax > other.imax ? imax : other.imax);
}

void IntRange::unionOrAssign(const IntRange& other, bool& union_)
{
    if (!union_ || imin > other.imin)
        imin = other.imin;
    if (!union_ || imax < other.imax)
        imax = other.imax;
    union_ = true;
}

void IntRange::splitBySign(IntRange& negRange, bool& hasNegRange,
                           IntRange& nonNegRange, bool& hasNonNegRange) const
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


#if !PERFORM_UNITTEST
const IntRange& IntRange::dump(const char* funcName, Expression *e) const
{
    printf("[(%c)%#018llx, (%c)%#018llx] @ %s ::: %s\n",
           imin.negative?'-':'+', (unsigned long long)imin.value,
           imax.negative?'-':'+', (unsigned long long)imax.value,
           funcName, e->toChars());
    return *this;
}
#endif

//------------------------------------------------------------------------------

#if PERFORM_UNITTEST
#include <cstdio>
#include <exception>

class AssertionError : public std::exception {
public:
    AssertionError() : std::exception() {}
};

void _assertPred(uinteger_t x, uinteger_t y, int line) {
    if (x != y) {
        printf("Line %d: %#018llx != %#018llx\n", line, x, y);
        throw AssertionError();
    }
}
void _assertPred(const SignExtendedNumber& x, const SignExtendedNumber& y, int line) {
    if (x != y) {
        printf("Line %d: (%c)%#018llx != (%c)%#018llx\n", line,
            x.negative?'-':'+', x.value,
            y.negative?'-':'+', y.value);
        throw AssertionError();
    }
}
void _assertPred(bool x, bool y, int line) {
    if (x != y) {
        static const char* const names[] = {"false", "true"};
        printf("Line %d: %s != %s\n", line, names[x], names[y]);
        throw AssertionError();
    }
}
#define assertPred(x, y) _assertPred(x, y, __LINE__)
#define RUN(testName) \
    try { \
        testName(); \
    } catch (const AssertionError&) { \
        printf("********" #testName " failed\n"); \
    }

void testAssertSanity() {
    int saneCount = 0;

    printf("Testing 'assert' sanity. You should see 3 assertion failures below\n");

    assertPred(true, true);
    try {
        assertPred(true, false);
    } catch (const AssertionError&) {
        ++ saneCount;
    }

    assertPred(4ULL, 4ULL);
    try {
        assertPred(3ULL, -3ULL);
    } catch (const AssertionError&) {
        ++ saneCount;
    }

    assertPred(SignExtendedNumber(5, false), SignExtendedNumber(5, false));
    try {
        assertPred(SignExtendedNumber(4, false), SignExtendedNumber(4, true));
    } catch (const AssertionError&) {
        ++ saneCount;
    }

    printf("--------------\n");

    if (saneCount != 3) throw AssertionError();
}

void testNegation() {
    SignExtendedNumber s (4);
    SignExtendedNumber t = -s;
    assertPred(t.value, -4ULL);
    assertPred(t.negative, true);

    s = SignExtendedNumber::max();
    t = -s;
    assertPred(t.value, 1);
    assertPred(t.negative, true);

    s = SignExtendedNumber::fromInteger(-4);
    assertPred(s.value, -4ULL);
    assertPred(s.negative, true);

    t = -s;
    assertPred(t.value, 4);
    assertPred(t.negative, false);

    s = SignExtendedNumber::min();
    t = -s;
    assertPred(t.value, UINT64_MAX);
    assertPred(t.negative, false);

    s = SignExtendedNumber(0);
    t = -s;
    assertPred(t.value, 0);
    assertPred(t.negative, false);
}

void testCompare() {
    SignExtendedNumber a = SignExtendedNumber::min();
    SignExtendedNumber b = SignExtendedNumber(-5, true);
    SignExtendedNumber c = SignExtendedNumber(0, false);
    SignExtendedNumber d = SignExtendedNumber(5, false);
    SignExtendedNumber e = SignExtendedNumber::max();

    assertPred(a == a, true);
    assertPred(a != a, false);
    assertPred(a < b, true);
    assertPred(b < c, true);
    assertPred(c < d, true);
    assertPred(d < e, true);
    assertPred(a < c, true);
    assertPred(c < e, true);
    assertPred(b < d, true);
    assertPred(b < a, false);
    assertPred(c < b, false);
    assertPred(d < c, false);
    assertPred(e < d, false);
    assertPred(e < c, false);
    assertPred(d < b, false);
    assertPred(c < a, false);

    assertPred(a, a);
    assertPred(SignExtendedNumber::extreme(false), SignExtendedNumber::max());
    assertPred(SignExtendedNumber::extreme(true), SignExtendedNumber::min());
}

void testAddition() {
    assertPred(SignExtendedNumber(4, false) + SignExtendedNumber(8, false),
               SignExtendedNumber(12, false));
    assertPred(SignExtendedNumber(4, false) + SignExtendedNumber(-9, true),
               SignExtendedNumber(-5, true));
    assertPred(SignExtendedNumber(-9, true) + SignExtendedNumber(4, false),
               SignExtendedNumber(-5, true));
    assertPred(SignExtendedNumber(-4, true) + SignExtendedNumber(9, false),
               SignExtendedNumber(5, false));
    assertPred(SignExtendedNumber(9, false) + SignExtendedNumber(-4, true),
               SignExtendedNumber(5, false));
    assertPred(SignExtendedNumber(9, true) + SignExtendedNumber(-4, false),
               SignExtendedNumber(5, false));
    assertPred(SignExtendedNumber(-4, true) + SignExtendedNumber(-6, true),
               SignExtendedNumber(-10, true));
    assertPred(SignExtendedNumber::max() + SignExtendedNumber(1, false),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber(UINT64_MAX/2+1, false) + SignExtendedNumber(UINT64_MAX/2+1, false),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber::max() + SignExtendedNumber::min(),
               SignExtendedNumber(-1, true));
    assertPred(SignExtendedNumber::min() + SignExtendedNumber(-1, true),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber::max() + SignExtendedNumber::max(),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber::min() + SignExtendedNumber::min(),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber(1, true) + SignExtendedNumber(1, true),
               SignExtendedNumber::min());

    SignExtendedNumber x(0);
    assertPred(++x, SignExtendedNumber(1));
    x = SignExtendedNumber(-1, true);
    assertPred(++x, SignExtendedNumber(0));
    x = SignExtendedNumber::min();
    assertPred(++x, SignExtendedNumber(1, true));
    x = SignExtendedNumber::max();
    assertPred(++x, SignExtendedNumber::max());
}

void testSubtraction() {
    assertPred(SignExtendedNumber(4, false) - SignExtendedNumber(8, false),
               SignExtendedNumber(-4, true));
    assertPred(SignExtendedNumber(4, false) - SignExtendedNumber(-9, true),
               SignExtendedNumber(13, false));
    assertPred(SignExtendedNumber(-9, true) - SignExtendedNumber(4, false),
               SignExtendedNumber(-13, true));
    assertPred(SignExtendedNumber(-4, true) - SignExtendedNumber(9, false),
               SignExtendedNumber(-13, true));
    assertPred(SignExtendedNumber(9, false) - SignExtendedNumber(-4, true),
               SignExtendedNumber(13, false));
    assertPred(SignExtendedNumber(9, true) - SignExtendedNumber(-4, false),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber(-4, true) - SignExtendedNumber(-6, true),
               SignExtendedNumber(2, false));
    assertPred(SignExtendedNumber::max() - SignExtendedNumber(-1, true),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber::max() - SignExtendedNumber::max(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::max() - SignExtendedNumber::min(),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber::min() - SignExtendedNumber(1, false),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber(1, false) - SignExtendedNumber::min(),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber::min() - SignExtendedNumber::min(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(1, true) - SignExtendedNumber::min(),
               SignExtendedNumber(1, false));
}

void testMultiplication() {
    assertPred(SignExtendedNumber(4, false) * SignExtendedNumber(8, false),
               SignExtendedNumber(32, false));
    assertPred(SignExtendedNumber(4, false) * SignExtendedNumber(-9, true),
               SignExtendedNumber(-36, true));
    assertPred(SignExtendedNumber(-9, true) * SignExtendedNumber(4, false),
               SignExtendedNumber(-36, true));
    assertPred(SignExtendedNumber(-4, true) * SignExtendedNumber(9, false),
               SignExtendedNumber(-36, true));
    assertPred(SignExtendedNumber(9, false) * SignExtendedNumber(-4, true),
               SignExtendedNumber(-36, true));
    assertPred(SignExtendedNumber(9, true) * SignExtendedNumber(-4, false),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber(-4, true) * SignExtendedNumber(-6, true),
               SignExtendedNumber(24, false));
    assertPred(SignExtendedNumber::max() * SignExtendedNumber::max(),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber::max() * SignExtendedNumber(0),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::max() * SignExtendedNumber::min(),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber(0) * SignExtendedNumber::max(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) * SignExtendedNumber(0),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) * SignExtendedNumber::min(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::min() * SignExtendedNumber::max(),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber::min() * SignExtendedNumber(0),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::min() * SignExtendedNumber::min(),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber(-6, false) * SignExtendedNumber(2, false),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber(-6, false) * SignExtendedNumber(-2, true),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber::max() * SignExtendedNumber(-1, true),
               SignExtendedNumber(1, true));
    assertPred(SignExtendedNumber::max() * SignExtendedNumber(-2, true),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber::max() * SignExtendedNumber(2, false),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber::min() * SignExtendedNumber(2, false),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber::min() * SignExtendedNumber(-1, true),
               SignExtendedNumber::max());
}

void testDivision() {
    assertPred(SignExtendedNumber(4, false) / SignExtendedNumber(8, false),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(8, false) / SignExtendedNumber(4, false),
               SignExtendedNumber(2, false));
    assertPred(SignExtendedNumber(4, false) / SignExtendedNumber(-9, true),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(-9, true) / SignExtendedNumber(4, false),
               SignExtendedNumber(-2, true));
    assertPred(SignExtendedNumber(-4, true) / SignExtendedNumber(9, false),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(9, false) / SignExtendedNumber(-4, true),
               SignExtendedNumber(-2, true));
    assertPred(SignExtendedNumber(4, true) / SignExtendedNumber(-9, false),
               SignExtendedNumber(-1, true));
    assertPred(SignExtendedNumber(-6, true) / SignExtendedNumber(-4, true),
               SignExtendedNumber(1, false));
    assertPred(SignExtendedNumber::max() / SignExtendedNumber::max(),
               SignExtendedNumber(1));
    assertPred(SignExtendedNumber::max() / SignExtendedNumber(0),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber::max() / SignExtendedNumber::min(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) / SignExtendedNumber::max(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) / SignExtendedNumber(0),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber(0) / SignExtendedNumber::min(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::min() / SignExtendedNumber::max(),
               SignExtendedNumber(-1, true));
    assertPred(SignExtendedNumber::min() / SignExtendedNumber(0),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber::min() / SignExtendedNumber::min(),
               SignExtendedNumber(1));
    assertPred(SignExtendedNumber(-6, false) / SignExtendedNumber(2, false),
               SignExtendedNumber((~5ULL)>>1));
    assertPred(SignExtendedNumber(-6, false) / SignExtendedNumber(-2, true),
               SignExtendedNumber(3 | 1ULL<<63, true));
    assertPred(SignExtendedNumber::max() / SignExtendedNumber(-1, true),
               SignExtendedNumber(1, true));
    assertPred(SignExtendedNumber::min() / SignExtendedNumber(-1, true),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber::max() / SignExtendedNumber(1, false),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber::min() / SignExtendedNumber(1, false),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber::min() / SignExtendedNumber(2, false),
               SignExtendedNumber(-(1ULL << 63), true));
    assertPred(SignExtendedNumber::min() / SignExtendedNumber(-1024, true),
               SignExtendedNumber(1ULL << 54));
}

void testModulus() {
    assertPred(SignExtendedNumber(4, false) % SignExtendedNumber(8, false),
               SignExtendedNumber(4, false));
    assertPred(SignExtendedNumber(8, false) % SignExtendedNumber(4, false),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(4, false) % SignExtendedNumber(-9, true),
               SignExtendedNumber(4, false));
    assertPred(SignExtendedNumber(-9, true) % SignExtendedNumber(4, false),
               SignExtendedNumber(-1, true));
    assertPred(SignExtendedNumber(-4, true) % SignExtendedNumber(9, false),
               SignExtendedNumber(-4, true));
    assertPred(SignExtendedNumber(9, false) % SignExtendedNumber(-4, true),
               SignExtendedNumber(1, false));
    assertPred(SignExtendedNumber(4, true) % SignExtendedNumber(-9, false),
               SignExtendedNumber(-5, true));
    assertPred(SignExtendedNumber(-6, true) % SignExtendedNumber(-4, true),
               SignExtendedNumber(-2, true));
    assertPred(SignExtendedNumber::max() % SignExtendedNumber::max(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::max() % SignExtendedNumber(0),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::max() % SignExtendedNumber::min(),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber(0) % SignExtendedNumber::max(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) % SignExtendedNumber(0),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) % SignExtendedNumber::min(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::min() % SignExtendedNumber::max(),
               SignExtendedNumber(-1, true));
    assertPred(SignExtendedNumber::min() % SignExtendedNumber(0),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::min() % SignExtendedNumber::min(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(-6, false) % SignExtendedNumber(2, false),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(-6, false) % SignExtendedNumber(-2, true),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::max() % SignExtendedNumber(-1, true),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::min() % SignExtendedNumber(-1, true),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::max() % SignExtendedNumber(1, false),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::min() % SignExtendedNumber(1, false),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::min() % SignExtendedNumber(2, false),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber::min() % SignExtendedNumber(999, false),
               SignExtendedNumber(-160, true));
}

void testShift() {
    assertPred(SignExtendedNumber(0) << SignExtendedNumber(4),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) << SignExtendedNumber(74),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) << SignExtendedNumber(-5, true),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) << SignExtendedNumber::max(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) << SignExtendedNumber::min(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(1) << SignExtendedNumber(4),
               SignExtendedNumber(16));
    assertPred(SignExtendedNumber(1) << SignExtendedNumber(74),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber(1) << SignExtendedNumber(-5, true),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber(1) << SignExtendedNumber::max(),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber(1) << SignExtendedNumber::min(),
               SignExtendedNumber::max());
    assertPred(SignExtendedNumber(-1, true) << SignExtendedNumber(4),
               SignExtendedNumber(-16, true));
    assertPred(SignExtendedNumber(-1, true) << SignExtendedNumber(74),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber(-1, true) << SignExtendedNumber(-5, true),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber(-1, true) << SignExtendedNumber::max(),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber(-1, true) << SignExtendedNumber::min(),
               SignExtendedNumber::min());
    assertPred(SignExtendedNumber(0xabcdef) << SignExtendedNumber(12, false),
               SignExtendedNumber(0xabcdef000ULL));
    assertPred(SignExtendedNumber(0xabcdef) << SignExtendedNumber(40, false),
               SignExtendedNumber(0xabcdef0000000000ULL));
    assertPred(SignExtendedNumber(0xabcdef) << SignExtendedNumber(41, false),
               SignExtendedNumber::max());


    assertPred(SignExtendedNumber(0) >> SignExtendedNumber(4),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) >> SignExtendedNumber(74),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) >> SignExtendedNumber(-5, true),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) >> SignExtendedNumber::max(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(0) >> SignExtendedNumber::min(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(16) >> SignExtendedNumber(4),
               SignExtendedNumber(1));
    assertPred(SignExtendedNumber(16) >> SignExtendedNumber(74),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(16) >> SignExtendedNumber(-5, true),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(16) >> SignExtendedNumber::max(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(16) >> SignExtendedNumber::min(),
               SignExtendedNumber(0));
    assertPred(SignExtendedNumber(-32, true) >> SignExtendedNumber(4),
               SignExtendedNumber(-2, true));
    assertPred(SignExtendedNumber(-32, true) >> SignExtendedNumber(74),
               SignExtendedNumber(-1, true));
    assertPred(SignExtendedNumber(-32, true) >> SignExtendedNumber(-5, true),
               SignExtendedNumber(-1, true));
    assertPred(SignExtendedNumber(-32, true) >> SignExtendedNumber::max(),
               SignExtendedNumber(-1, true));
    assertPred(SignExtendedNumber(-32, true) >> SignExtendedNumber::min(),
               SignExtendedNumber(-1, true));
    assertPred(SignExtendedNumber(0xabcdef, false) >> SignExtendedNumber(12, false),
               SignExtendedNumber(0xabcULL));
    assertPred(SignExtendedNumber(0xabcdef, true) >> SignExtendedNumber(12, false),
               SignExtendedNumber(0xFFF0000000000ABCULL, true));
    assertPred(SignExtendedNumber::min() >> SignExtendedNumber(1, false),
               SignExtendedNumber(0x8000000000000000ULL, true));
    assertPred(SignExtendedNumber::min() >> SignExtendedNumber(63, false),
               SignExtendedNumber(-2, true));
    assertPred(SignExtendedNumber::min() >> SignExtendedNumber(65, false),
               SignExtendedNumber(-1, true));
}

void testFromNumbers() {
    SignExtendedNumber a[] = {
        SignExtendedNumber(12, false),
        SignExtendedNumber(-35, true),
        SignExtendedNumber(40, false),
        SignExtendedNumber(-21, true),
        SignExtendedNumber::min()
    };

    IntRange ir1 = IntRange::fromNumbers2(a);
    assertPred(ir1.imin, SignExtendedNumber(-35, true));
    assertPred(ir1.imax, SignExtendedNumber(12, false));

    IntRange ir2 = IntRange::fromNumbers2(a+1);
    assertPred(ir2.imin, SignExtendedNumber(-35, true));
    assertPred(ir2.imax, SignExtendedNumber(40, false));

    IntRange ir3 = IntRange::fromNumbers4(a);
    assertPred(ir3.imin, SignExtendedNumber(-35, true));
    assertPred(ir3.imax, SignExtendedNumber(40, false));

    IntRange ir4 = IntRange::fromNumbers4(a+1);
    assertPred(ir4.imin, SignExtendedNumber::min());
    assertPred(ir4.imax, SignExtendedNumber(40, false));

    assertPred(ir4.contains(ir3), true);
    assertPred(ir1.contains(ir2), false);

    IntRange ir5 = IntRange::widest();
    assertPred(ir5.imin, SignExtendedNumber::min());
    assertPred(ir5.imax, SignExtendedNumber::max());
    assertPred(ir5.contains(ir4), true);
}

void testContainsZero() {
    IntRange ir1 (SignExtendedNumber(0), SignExtendedNumber(4));
    assertPred(ir1.containsZero(), true);

    IntRange ir2 (SignExtendedNumber(-4, true), SignExtendedNumber(0));
    assertPred(ir2.containsZero(), true);

    IntRange ir3 (SignExtendedNumber(-5, true), SignExtendedNumber(5));
    assertPred(ir3.containsZero(), true);

    assertPred(IntRange::widest().containsZero(), true);

    IntRange ir4 (SignExtendedNumber(8), SignExtendedNumber(9));
    assertPred(ir4.containsZero(), false);

    IntRange ir5 (SignExtendedNumber(-5, true), SignExtendedNumber(-2, true));
    assertPred(ir5.containsZero(), false);

    IntRange ir6 (SignExtendedNumber(0), SignExtendedNumber(0));
    assertPred(ir6.containsZero(), true);
}

void testCast() {
    {
        IntRange ir1 (SignExtendedNumber(0), SignExtendedNumber(0xFFFF));
        ir1.castUnsigned(0xFF);
        assertPred(ir1.imin, SignExtendedNumber(0));
        assertPred(ir1.imax, SignExtendedNumber(0xFF));

        IntRange ir2 (SignExtendedNumber(0x101), SignExtendedNumber(0x105));
        ir2.castUnsigned(0xFF);
        assertPred(ir2.imin, SignExtendedNumber(1));
        assertPred(ir2.imax, SignExtendedNumber(5));

        IntRange ir3 (SignExtendedNumber(-7, true), SignExtendedNumber(7, false));
        ir3.castUnsigned(0xFF);
        assertPred(ir3.imin, SignExtendedNumber(0));
        assertPred(ir3.imax, SignExtendedNumber(0xFF));

        IntRange ir4 (SignExtendedNumber(0x997F), SignExtendedNumber(0x9999));
        ir4.castUnsigned(0xFF);
        assertPred(ir4.imin, SignExtendedNumber(0x7F));
        assertPred(ir4.imax, SignExtendedNumber(0x99));

        IntRange ir5 (SignExtendedNumber(-1, true), SignExtendedNumber(1, false));
        ir5.castUnsigned(UINT64_MAX);
        assertPred(ir5.imin, SignExtendedNumber(0));
        assertPred(ir5.imax, SignExtendedNumber::max());

        IntRange ir6 (SignExtendedNumber::min(), SignExtendedNumber(0));
        ir6.castUnsigned(UINT64_MAX);
        assertPred(ir6.imin, SignExtendedNumber(0));
        assertPred(ir6.imax, SignExtendedNumber::max());

        IntRange ir7 (SignExtendedNumber::min(), SignExtendedNumber(-0x80, true));
        ir7.castUnsigned(UINT64_MAX);
        assertPred(ir7.imin, SignExtendedNumber(0));
        assertPred(ir7.imax, SignExtendedNumber(-0x80, false));

        IntRange ir8 = IntRange::widest();
        ir8.castUnsigned(0xFF);
        assertPred(ir8.imin, SignExtendedNumber(0));
        assertPred(ir8.imax, SignExtendedNumber(0xFF));
    }

    {
        IntRange ir1 (SignExtendedNumber(0), SignExtendedNumber(0xFFFF));
        ir1.castSigned(0xFF);
        assertPred(ir1.imin, SignExtendedNumber(-0x80, true));
        assertPred(ir1.imax, SignExtendedNumber(0x7F, false));

        IntRange ir2 (SignExtendedNumber(0x101), SignExtendedNumber(0x105));
        ir2.castSigned(0xFF);
        assertPred(ir2.imin, SignExtendedNumber(1));
        assertPred(ir2.imax, SignExtendedNumber(5));

        IntRange ir3 (SignExtendedNumber(-7, true), SignExtendedNumber(7, false));
        ir3.castSigned(0xFF);
        assertPred(ir3.imin, SignExtendedNumber(-7, true));
        assertPred(ir3.imax, SignExtendedNumber(7, false));

        IntRange ir4 (SignExtendedNumber(0x997F), SignExtendedNumber(0x9999));
        ir4.castSigned(0xFF);
        assertPred(ir4.imin, SignExtendedNumber(-0x80, true));
        assertPred(ir4.imax, SignExtendedNumber(0x7F, false));

        IntRange ir5 (SignExtendedNumber(-0xFF, true), SignExtendedNumber(-0x80, true));
        ir5.castSigned(0xFF);
        assertPred(ir5.imin, SignExtendedNumber(-0x80, true));
        assertPred(ir5.imax, SignExtendedNumber(0x7F, false));

        IntRange ir6 (SignExtendedNumber(-0x80, true), SignExtendedNumber(-0x80, true));
        ir6.castSigned(0xFF);
        assertPred(ir6.imin, SignExtendedNumber(-0x80, true));
        assertPred(ir6.imax, SignExtendedNumber(-0x80, true));

        IntRange ir7 = IntRange::widest();
        ir7.castSigned(0xFFFFFFFFULL);
        assertPred(ir7.imin, SignExtendedNumber(-0x80000000ULL, true));
        assertPred(ir7.imax, SignExtendedNumber( 0x7FFFFFFFULL, false));
    }

    {
        IntRange ir1 (SignExtendedNumber(0), SignExtendedNumber(0x9999));
        ir1.castDchar();
        assertPred(ir1.imin, SignExtendedNumber(0));
        assertPred(ir1.imax, SignExtendedNumber(0x9999));

        IntRange ir2 (SignExtendedNumber(0xFFFF), SignExtendedNumber(0x7FFFFFFF));
        ir2.castDchar();
        assertPred(ir2.imin, SignExtendedNumber(0xFFFF));
        assertPred(ir2.imax, SignExtendedNumber(0x10FFFF));

        IntRange ir3 = IntRange::widest();
        ir3.castDchar();
        assertPred(ir3.imin, SignExtendedNumber(0));
        assertPred(ir3.imax, SignExtendedNumber(0x10FFFF));
    }
}

void testAbsNeg() {
    IntRange ir1 = IntRange(SignExtendedNumber(5), SignExtendedNumber(104)).absNeg();
    assertPred(ir1.imin, SignExtendedNumber(-104, true));
    assertPred(ir1.imax, SignExtendedNumber(-5, true));

    IntRange ir2 = IntRange(SignExtendedNumber(-46, true), SignExtendedNumber(-3, true)).absNeg();
    assertPred(ir2.imin, SignExtendedNumber(-46, true));
    assertPred(ir2.imax, SignExtendedNumber(-3, true));

    IntRange ir3 = IntRange(SignExtendedNumber(-7, true), SignExtendedNumber(9)).absNeg();
    assertPred(ir3.imin, SignExtendedNumber(-9, true));
    assertPred(ir3.imax, SignExtendedNumber(0));

    IntRange ir4 = IntRange(SignExtendedNumber(-12, true), SignExtendedNumber(2)).absNeg();
    assertPred(ir4.imin, SignExtendedNumber(-12, true));
    assertPred(ir4.imax, SignExtendedNumber(0));

    IntRange ir5 = IntRange::widest().absNeg();
    assertPred(ir5.imin, SignExtendedNumber::min());
    assertPred(ir5.imax, SignExtendedNumber(0));

    IntRange ir6 = IntRange(SignExtendedNumber(0), SignExtendedNumber::max()).absNeg();
    assertPred(ir6.imin, SignExtendedNumber(1, true));
    assertPred(ir6.imax, SignExtendedNumber(0));
}

int main() {
    RUN(testAssertSanity);
    RUN(testNegation);
    RUN(testCompare);
    RUN(testAddition);
    RUN(testSubtraction);
    RUN(testMultiplication);
    RUN(testDivision);
    RUN(testModulus);
    RUN(testShift);
    RUN(testFromNumbers);
    RUN(testContainsZero);
    RUN(testCast);
    RUN(testAbsNeg);
    printf("Finished all tests.\n");
}


#endif


