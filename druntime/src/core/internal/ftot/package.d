/// Floating to text conversion
module core.internal.ftot;

import core.internal.ftot.decimal;
import core.internal.string: unsignedToTempString, unsignedToTempStringTrailingZerosHandling;

nothrow:
@safe:

unittest
{
    char[100] buf = '|';
    // Just in case of debugging using stdc:
    buf[$-1] = '\0';

    void testIt(T)(T v, string expected, ushort precision = 6)
    {
        char[] res;

        res = dtoa_puff!(true, true, uint)(buf, v, precision, false);
        assert(res == expected);

        res = dtoa_puff!(true, true, ushort)(buf, v, precision, false);
        assert(res == expected);
    }

    testIt(-12.345f, "-1.2345e+01");
    testIt(-12.345f, "-1.2345e+01", 5);
    testIt(2.0, "2.0e+00");
    testIt(-1.23456789101112, "-1.23457e+00");
    testIt(0.0000123456789, "1.23457e-05");
}

/**
Converts an floating value to a string of characters.

Can be used when compiling with -betterC. Does not allocate memory.

Params:
    value = the floating value to convert
    buf   = the pre-allocated buffer used to store the result
    precision = required count of significant digits
    enableTrailingZeroes = add zeros as end filler

Returns:
    The floating value as a string of characters
*/
char[] floatingToTempString(bool expForm, bool stdcCompat, T)(T value, return scope char[] buf, in ushort precision, bool enableTrailingZeroes) @nogc
if(__traits(isFloating, T))
{
    static if(size_t.sizeof == 4)
        alias BigitType = ushort;
    else
        alias BigitType = uint;

    version(assert)
    {
        const bufLen = maxOutputBufSize!(BigitType, T, expForm) + (expForm ? precision : 0);
        assert(buf.length >= bufLen);
    }

    char[] slice = dtoa_puff!(expForm, stdcCompat, BigitType)(buf, value, precision, enableTrailingZeroes);

    return slice;
}

unittest
{
    char[21] buf;
    auto r = floatingToTempString!(true, true)(-123.456789, buf, 6, false);

    assert(r == "-1.23457e+02");
}

version(linux)
    version = ComparisonWithLibc;
else version(Windows)
    version = ComparisonWithLibc;

unittest
{
    static void testIt(T)(T val, string phobos_std, string phobos_exp, in size_t line)
    {
        char[10] lineBuf;
        const testOnLine = ` (test on line `~unsignedToTempString(line, lineBuf)~`)`;

        const precision = 7;

        {
            void cmp(alias BigitType, bool expForm)()
            {
                enum bufLen = maxOutputBufSize!(BigitType, T, expForm) + (expForm ? precision : 0);
                // For convenient debugging with printf():
                char[bufLen] buf = 'x';
                buf[$-1] = '\0';

                const shouldBe = expForm ? phobos_exp : phobos_std;

                if(shouldBe == "disabled")
                    return;

                const r = dtoa_puff!(expForm, false, BigitType)(buf, val, precision, false);

                assert(r == shouldBe, `"`~r~`" but expected "`~shouldBe~`" (as implemented in Phobos, expForm=`~(expForm ? "true" : "false")~`)`~testOnLine);
            }

            cmp!(ushort, false);
            cmp!(ushort, true);
            cmp!(uint, false);
            cmp!(uint, true);
        }

        version(ComparisonWithLibc)
        {
            static string fmtStr(bool expForm)
            {
                static if(!is(T==real))
                    return expForm ? "%e" : "%f";
                else
                    return expForm ? "%Le" : "%Lf";
            }

            static string getLibcText(T val, bool expForm) @trusted
            {
                import core.stdc.stdio: snprintf;

                const fmt = fmtStr(expForm);

                char[5000] buf;
                auto len = snprintf(buf.ptr, buf.length, &fmt[0], val);
                assert(len > 0);
                assert(len <= buf.length);

                return buf[0 .. len].idup;
            }

            void libcCmp(alias BigitType, bool expForm)()
            {
                /*
                The Microsoft C++ compiler treats long double the same
                as double, so the C runtime also doesn't have support
                for floating point numbers larger than double.
                */
                version(Windows)
                    static if(is(T == real))
                        return;

                const stdcText = getLibcText(val, expForm);

                enum bufLen = maxOutputBufSize!(BigitType, T, expForm) + (expForm ? precision : 0);
                char[bufLen] buf = 'x';
                buf[$-1] = '\0';

                const asLibc = dtoa_puff!(expForm, true, BigitType)(buf, val, precision, true);

                assert(asLibc == stdcText, `"`~asLibc~`" but stdc snprintf("`~fmtStr(expForm)~`") returns: "`~stdcText~`"`~testOnLine);
            }

            libcCmp!(ushort, false);
            libcCmp!(ushort, true);
            libcCmp!(uint, false);
            libcCmp!(uint, true);
        }
    }

    // Test on all posible types
    static void onAll(T, ARGS...)(T val, ARGS args, in size_t line = __LINE__)
    {
        static if(T.dig <= float.dig)
            testIt(float(val), args, line);

        static if(T.dig <= double.dig)
            testIt(double(val), args, line);

        static if(T.dig <= real.dig)
            testIt(real(val), args, line);
    }

    onAll(1.0f, "1", "1e+00");
    onAll(0.0f, "0", "0e+00");
    onAll(float.nan, "nan", "nan");
    onAll(float.infinity, "inf", "inf");
    onAll(-float.infinity, "-inf", "-inf");
    onAll(-123.45678f, "-123.456779", "-1.234568e+02");
    onAll(1e3f, "1000", "1e+03");
    onAll(0.001f, "0.001", "1e-03");
    onAll(-1.0e-8f, "-0", "-1e-08");
    onAll(-3.75733371660706733e+254, "-375733371660706733350021703837468260693310962815288025942112652778731979228624690746182101684187633634076761835259805303946874579012812170352826319278230807411175518153951956765533871792968837984915446671623313976187557599924035579899807743068455080820736", "-3.757334e+254");
    onAll(-3.75733371660706733e-254, "-0", "-3.757334e-254");
    onAll(float.max, "340282346638528859811704183484516925440" /* well-known maximum 32 bit IEEE-754 floating value */, "3.402823e+38");
    onAll(-float.max, "-340282346638528859811704183484516925440" /* ditto */, "-3.402823e+38");
    onAll(double.max, "179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368", "1.797693e+308");
    onAll(-double.max, "-179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368", "-1.797693e+308");

    // Comparison with a predefined string is disabled because it would have to be a huge string
    onAll(real.max, "disabled", "disabled");
    onAll(-real.max, "disabled", "disabled");

    // Very small values
    onAll(float.min_normal, "0", "1.175494e-38");
    onAll(double.min_normal, "0", "2.225074e-308");
    onAll(real.min_normal, "0", "disabled" /* platform-dependent */);
}

/// Returns: immutable portion of needed resulting buffer size.
/// Does not adds variable precision part for scientific notation.
template maxOutputBufSize(BigitType, F, bool expForm)
if(__traits(isFloating, F))
{
    static assert(F.max_10_exp <= 9999 && -F.min_10_exp <= 9999);

    static if(F.max_10_exp > 999 && -F.min_10_exp > 999)
        enum expLen = 4;
    else static if(F.max_10_exp > 99 && -F.min_10_exp > 99)
        enum expLen = 3;
    else
        enum expLen = 2;

    mixin BigitsArraySizeCalculation!(BigitType, F);

    static if(expForm)
    {
        // -0.12345e-123
        enum maxOutputBufSize = 1 /* sign */ + (decimalExp-1) /* possible leading zeros */ + 1 /* dot */ + 2 /* e with sign */ + expLen;
    }
    else
    {
        enum totalDigits = initialDigits + maxShifts * decimalExp;

        // -1234567890.1234567
        enum maxOutputBufSize = 1 /* sign */ + 1 /* dot */ + totalDigits;
    }
}

char[] dtoa_puff(bool expForm, bool stdcCompat, T, F)(return scope char[] buf, F val, ushort precision, in bool enableTrailingZeros)
{
    static char[] setRet(return scope char[] buf, string s)
    {
        auto ret = buf[0 .. s.length];
        ret[] = s[0 .. $];
        return ret;
    }

    // Special cases
    if(val != val)
        return setRet(buf, "nan");
    else if(val > F.max)
        return setRet(buf, "inf");
    else if(val < -F.max)
        return setRet(buf, "-inf");

    mixin BigitsArraySizeCalculation!(T, F);
    const d = Decimal!(T, bigitsArrLength)(val);

    uint bigitIndex;

    void blockOut(bool enableLeadingZeros)()
    {
        ref const bigit = d.bigits[bigitIndex];

        const end = count + d.decimalExp;
        auto block = buf[count .. end];

        const digitsLen = to_chars_reverse(block, bigit);
        assert(digitsLen <= d.decimalExp);

        static if(enableLeadingZeros)
        {
            block[0 .. $ - digitsLen] = '0';
            digitsCount += block.length;
        }
        else
            digitsCount += digitsLen;

        count = end;
        bigitIndex++;
    }

    // First bigit output
    size_t digitsCount;
    size_t count = 1; // possible minus sign
    size_t firstDigitIdx;

    if(!expForm && d.fractionStart <= 0)
    {
        // At first need to add leading zeros
        auto zNum = -d.fractionStart * d.decimalExp;
        if(zNum > precision)
            zNum = precision;

        firstDigitIdx = count;
        const end = count + zNum + 1;
        buf[count .. end] = '0';
        count = end;

        digitsCount += zNum;

        blockOut!true;
    }
    else
    {
        blockOut!false;
        firstDigitIdx = count - digitsCount;
    }

    size_t startIdx = firstDigitIdx;
    if(val < 0)
        buf[--startIdx] = '-';

    static if(!expForm)
    {
        size_t dotPlace = d.fractionStart <= 0 ? 1 : digitsCount;
    }
    else
    {
        const dotPlace = 1;
        const remainedIntDigits = (d.fractionStart - bigitIndex) * d.decimalExp;
        int exp = cast(int)digitsCount - dotPlace + remainedIntDigits;
    }

    assert(dotPlace > 0);

    // Remaining bigits output
    while(bigitIndex < d.numBigits)
    {
        static if(expForm)
            const currPrecision = digitsCount;
        else
        {
            const onIntegerPart = (bigitIndex < d.fractionStart);
            const currPrecision = onIntegerPart ? 0 : digitsCount - dotPlace;
        }

        if(currPrecision > precision)
            break;

        blockOut!true;

        static if(!expForm)
        {
            if(onIntegerPart && d.fractionStart > 0)
                    dotPlace = digitsCount;
        }
    }

    static if(!expForm)
    {
        // Precision value is taken into account only after dot
        precision += dotPlace - 1;
    }

    if(digitsCount > precision)
    {
        auto toRound = buf[firstDigitIdx .. count];
        count += precision - toRound.length;
        auto deltaExp = round(toRound, precision, d.bigits[bigitIndex .. $]);

        static if(expForm)
            exp += deltaExp;

        digitsCount = precision;
    }

    // Add decimal dot
    const dotIdx= firstDigitIdx + dotPlace;

    if(stdcCompat || dotIdx != count)
    {
        count++;

        //TODO: char-by-char shift is too slow
        //1. Split integral and fractional parts to completely avoid such shifts for output by write()
        //2. Implement automatic choice of shifting direction to avoid too much iterations during formatting
        foreach_reverse(i; dotIdx .. count)
            buf[i] = buf[i-1];

        buf[dotIdx] = '.';
    }

    if(enableTrailingZeros)
    {
        for(; digitsCount < precision; digitsCount++)
            buf[count++] = '0';
    }
    else
    {
        static if(stdcCompat)
        {
            // Special case for adding 0 after dot if no more digits after dot
            if(dotIdx == count - 1)
                buf[count++] = '0';
        }

        // Remove trailing zeros
        for(; count > dotIdx; count--)
        {
            const c = buf[count-1];

            static if(stdcCompat)
            {
                if(buf[count-2] == '.')
                    break;
            }
            else
            {
                if(c == '.')
                {
                    count--;
                    break;
                }
            }

            if(c != '0')
                break;
        }
    }

    static if(expForm)
        exponentOutput!stdcCompat(buf, count, exp);

    return buf[startIdx .. count];
}

private auto round(T)(return scope char[] buf, in uint precision, in T[] notProcessedBigits) pure
{
    // Checks: exactly 0.5 or a little higher?
    bool hasNonzero()
    {
        foreach(i, ref c; buf[precision + 1 .. $])
            if(c != '0')
                return true;

        foreach(i, ref b; notProcessedBigits)
            if(b != 0)
                return true;

        return false;
    };

    int expDelta;
    const digit = buf[precision];

    if(digit > '5' || (digit == '5' && ((buf[precision - 1] % 2) == 1 || hasNonzero)))
    {
        int i = precision - 1;

        while(i >= 0 && buf[i] == '9')
            buf[i--] = '0';

        if(i >= 0)
            buf[i]++;
        else
        {
            buf[0] = '1';
            expDelta++;
        }
    }

    return expDelta;
}

private void exponentOutput(bool stdcCompat)(char[] buf, ref size_t count, int exp) pure
in(exp <= 9999)
in(exp >= -9999)
{
    buf[count++] = 'e';

    version(all)
    {
        if(exp >= 0)
            buf[count] = '+';
        else
        {
            buf[count] = '-';
            exp = -exp;
        }

        count++;

        if(exp > 99)
        {
            auto digits = unsignedToTempString(exp);

            const end = count + digits.length;
            buf[count .. end] = digits;
            count = end;

            return;
        }

        const tens = exp / 10;
        buf[count++] = cast(char)('0' + tens);
        buf[count++] = cast(char)('0' + exp % 10);
    }
}

/// Same as C++ std::to_chars but outputs from right boundary
private size_t to_chars_reverse(T)(scope char[] buf, T val, bool noTrailingZeros = false) pure
if(__traits(isUnsigned, T))
{
    char[] digits;

    if(noTrailingZeros)
        digits = unsignedToTempStringTrailingZerosHandling!(10, false, false)(val, buf);
    else
        digits = unsignedToTempStringTrailingZerosHandling!(10, false, true)(val, buf);

    return digits.length;
}
