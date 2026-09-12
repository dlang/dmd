///
module core.internal.ftot.decimal;

pure:
nothrow:
@nogc:
@safe:

package:

mixin template Estimation(BigitT)
if(is(BigitT == ushort) || is(BigitT == uint))
{
    // Set decimal exponent. The most effective is to use
    // the largest power of 10 that is less than T.max.
    static if(BigitT.sizeof == 4)
    {
        enum decimalExp = 9; // 10^9 - largest decimal number less than 32-bit value
        enum bigitBitWidth = 29; // 2^29 - largest binary number less than 10^9
        alias UL = ulong; // Twice longer than BigitT
    }
    else static if(BigitT.sizeof == 2)
    {
        enum decimalExp = 4; // 10^4 - largest decimal number less than 16-bit value
        enum bigitBitWidth = 13; // 2^13 - largest binary number less than 10^4
        alias UL = uint;
    }
}

mixin template BigitsArraySizeCalculation(BigitT, F)
if(__traits(isFloating, F))
{
    enum isNotReal = !is(F == real) ||
        (
            real.mant_dig == double.mant_dig
            && real.min_10_exp == double.min_10_exp
            && real.max_10_exp == double.max_10_exp
        );

    mixin Estimation!BigitT;

    enum intPartBigitsNum = F.mant_dig / bigitBitWidth + (F.mant_dig % bigitBitWidth == 0 ? 0 : 1);

    static if(is(F == float) || (UL.sizeof == 8 && isNotReal))
    {
        /// A type that is guaranteed to fit a integral part of floating T (except "real")
        alias GF = UL;
    }
    else
    {
        static if(isNotReal)
            static assert(intPartBigitsNum == 5);

        alias GF = ulong;
    }

    private
    {
        enum maxLeftShifts = (F.max_10_exp + decimalExp-1) / decimalExp;
        enum maxRightShifts = (-F.min_10_exp + decimalExp-1) / decimalExp;
    }

    enum initialDigits = 1 /* digit before dot */ + F.max_10_exp + (-F.min_10_exp) + F.dig;
    enum maxShifts = maxLeftShifts < maxRightShifts ? maxRightShifts : maxLeftShifts;

    enum bigitsArrLength = (initialDigits + decimalExp-1) / decimalExp + maxShifts;
}

/**
 * A fixed-point decimal number.
 *
 * Implements a fixed-point decimal number using a base-10^9 positional system.
 * It represents large numbers by breaking them into "bigits" (blocks),
 * where each block is a 9-digit decimal integer stored in a integer type.
 *
 * Params:
 *  T = unsigned integer of size 16 or 32
 *  maxLen = bigits array size
 */
struct Decimal(T, ushort maxLen)
if(is(T == ushort) || is(T == uint))
{
    private T[maxLen] bigitsArr = void;
    T[] bigits;

    mixin Estimation!T;

    static assert(decimalExp <= bigitBitWidth);

    private enum maxLeftShift = bigitBitWidth;
    enum T bigitBound = 10 ^^ decimalExp;

    ushort numBigits;
    short fractionStart;

    void shiftFewBitsLeft(in int n)
    in(n > 0)
    in(n <= maxLeftShift)
    {
        enum byte bigitIdx = 0;

        // Will number of blocks increase after the shifting?
        // If so, reserves space for a new block
        const ubyte offset = bigits[bigitIdx] >= (bigitBound >> n) ? 1 : 0;
        T carry;

        foreach_reverse(i; bigitIdx .. numBigits)
        {
            UL bigit = bigits[i];
            bigit = (bigit << n) + carry;

            if(bigit < bigitBound)
                carry = 0;
            else
            {
                carry = assumeSafeCastT(bigit / bigitBound);
                bigit = bigit % bigitBound;
            }

            bigits[i + offset] = assumeSafeCastT(bigit);
        }

        if(offset != 0)
        {
            bigits[bigitIdx] = carry;
            numBigits++;
        }
    }

    void shiftFewBitsRight(in int n)
    in(n > 0)
    in(n <= decimalExp)
    {
        const T mask = assumeSafeCastT((1 << n) - 1);
        T borrow;
        int offset;

        // Number was here and moved completely to the right?
        if((bigits[0] >> n) == 0 && bigits[0] != 0)
        {
            offset = 1;
            numBigits--;
            fractionStart--;

            borrow = assumeSafeCastT(UL(bigits[0]) * bigitBound >> n);
        }

        foreach(i; 0 .. numBigits)
        {
            const UL bigit = bigits[i + offset];

            bigits[i] = assumeSafeCastT(borrow + (bigit >> n));
            borrow = assumeSafeCastT((bigit & mask) * bigitBound >> n);
        }

        if(borrow != 0)
        {
            bigits[numBigits] = borrow;
            numBigits++;
        }
    }

    void massiveLeftShift(int n)
    in(n > 0)
    {
        enum bitsPerIteration = maxLeftShift;

        do
        {
            const bits = n < bitsPerIteration ? n : bitsPerIteration;
            shiftFewBitsLeft(bits);
            n -= bits;
        }
        while(n > 0);
    }

    void massiveRightShift(int n)
    in(n > 0)
    {
        enum bitsPerIteration = decimalExp;

        do
        {
            const bits = n < bitsPerIteration ? n : bitsPerIteration;
            shiftFewBitsRight(bits);
            n -= bits;
        }
        while(n > 0);
    }

    this(F)(F d)
    if(__traits(isFloating, F))
    {
        import core.stdc.math;

        mixin BigitsArraySizeCalculation!(T, F);
        static assert(maxLen <= bigitsArrLength);

        enum numBits = d.mant_dig;
        int exp; // in fact, exponent value always fits into a short type

        static if(is(F == float))
            const integralPart = frexpf(d, &exp) * (1U << numBits);
        else static if(is(F == double) || isNotReal)
            const integralPart = frexp(cast(double) d, &exp) * (1UL << numBits);
        else static if(is(F == real))
            auto mant = frexpl(d, &exp).fabsl;

        exp -= numBits;

        byte intPartIdx = intPartBigitsNum;

        void addIntPartAsInteger(GF v)
        {
            while(true)
            {
                assert(intPartIdx > 0);
                intPartIdx--;

                const lessSig = v % bigitBound;
                v /= bigitBound;

                bigitsArr[intPartIdx] = lessSig;
                numBigits++;

                if(v == 0)
                    break;
            }
        }

        static if(isNotReal)
        {
            auto v = cast(GF) (integralPart < 0 ? -integralPart : integralPart);
            addIntPartAsInteger(v);
        }
        else
        {{
            // Fetch unsigned values from a big mantiss

            version(assert)
            {
                //TODO: implement our own scalbnl() using core.internal.convert to achieve pure ctor
                import core.stdc.errno;
                import core.stdc.fenv;

                errno = 0;
                () @trusted { feclearexcept(FE_ALL_EXCEPT); }();
            }

            short shift = F.mant_dig;

            while(true)
            {
                if(shift == 0)
                {
                    const word = cast(GF) mant;
                    addIntPartAsInteger(word);
                    break;
                }

                const scaled = scalbnl(mant, shift);
                () @trusted {
                    assert(fetestexcept(FE_OVERFLOW|FE_UNDERFLOW) == 0);
                }();

                const word = cast(GF) scaled;
                addIntPartAsInteger(word);

                // Remove fetched bits
                mant -= scalbnl(cast(real) word, -shift);
                () @trusted {
                    assert(fetestexcept(FE_OVERFLOW|FE_UNDERFLOW) == 0);
                }();

                if(mant < mant.epsilon)
                    break;

                shift -= bigitBitWidth;

                // In case incomplete last word when .mant_dig isn't multiple of bigitBitWidth
                static if(F.mant_dig % bigitBitWidth != 0)
                    if(shift < 0)
                        shift = 0;
            }
        }}

        assert(intPartIdx >= 0);

        // Skip leading zero bigits
        () @trusted {
            bigits = bigitsArr[intPartIdx .. $];
        }();

        if(exp >= 0)
        {
            massiveLeftShift(exp);
            fractionStart = numBigits;
        }
        else
        {
            const integralBigitsAcquired = intPartBigitsNum - intPartIdx;
            fractionStart = integralBigitsAcquired;

            massiveRightShift(-exp);
        }

        // Assigning again for better boundary control
        version(D_NoBoundsChecks){} else
        bigits = bigits[0 .. numBigits + 1];
    }

    private static T assumeSafeCastT(V)(V val, size_t line = __LINE__)
    if(__traits(isIntegral, V))
    {
        assert(val >= 0);
        assert(val <= T.max);

        return cast(T) val;
    }
}


unittest
{
    double val = 9999999.0;
    auto d = Decimal!(uint, 20)(val);
    d.bigitsArr = 0; // resets bigits storage

    d.bigits[0] = 1;

    d.shiftFewBitsLeft(1);
    assert(d.bigits[0] == 2);

    d.shiftFewBitsLeft(d.maxLeftShift);
    assert(d.bigits[0] == 1);
}

unittest
{
    double val = 123.456;
    auto d = Decimal!(uint, 16)(val);
    d.numBigits = 2;

    const initial = d.bigits;

    // Shift right to 32 bits:
    d.shiftFewBitsRight(1);
    d.shiftFewBitsRight(2);
    d.shiftFewBitsRight(5);
    d.shiftFewBitsRight(8);
    d.shiftFewBitsRight(8);
    d.shiftFewBitsRight(8);

    // Shift left to the initial state:
    d.shiftFewBitsLeft(1);
    d.shiftFewBitsLeft(2);
    d.shiftFewBitsLeft(5);
    d.shiftFewBitsLeft(8);
    d.shiftFewBitsLeft(16);

    assert(initial[0 .. 2] == d.bigits[0 .. 2]);
}
