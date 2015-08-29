
/**********************************************
 * This module implements integral arithmetic primitives that check
 * for out-of-range results.
 *
 * Integral arithmetic operators operate on fixed width types.
 * Results that are not representable in those fixed widths are silently
 * truncated to fit.
 * This module offers integral arithmetic primitives that produce the
 * same results, but set an 'overflow' flag when such truncation occurs.
 * The setting is sticky, meaning that numerous operations can be cascaded
 * and then the flag need only be checked at the end.
 * Whether the operation is signed or unsigned is indicated by an 's' or 'u'
 * suffix, respectively. While this could be achieved without such suffixes by
 * using overloading on the signedness of the types, the suffix makes it clear
 * which is happening without needing to examine the types.
 *
 * While the generic versions of these functions are computationally expensive
 * relative to the cost of the operation itself, compiler implementations are free
 * to recognize them and generate equivalent and faster code.
 *
 * References: $(LINK2 http://blog.regehr.org/archives/1139, Fast Integer Overflow Checks)
 * Copyright: Copyright (c) Walter Bright 2014.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Walter Bright
 * Source:    $(DRUNTIMESRC core/_checkedint.d)
 */

module core.checkedint;

nothrow:
@safe:
@nogc:
pure:

/*******************************
 * Add two signed integers, checking for overflow.
 *
 * The overflow is sticky, meaning a sequence of operations can
 * be done and overflow need only be checked at the end.
 * Params:
 *      x = left operand
 *      y = right operand
 *      overflow = set if an overflow occurs, is not affected otherwise
 * Returns:
 *      the sum
 */

pragma(inline, true)
int adds(int x, int y, ref bool overflow)
{
    long r = cast(long)x + cast(long)y;
    if (r < int.min || r > int.max)
        overflow = true;
    return cast(int)r;
}

unittest
{
    bool overflow;
    assert(adds(2, 3, overflow) == 5);
    assert(!overflow);
    assert(adds(1, int.max - 1, overflow) == int.max);
    assert(!overflow);
    assert(adds(int.min + 1, -1, overflow) == int.min);
    assert(!overflow);
    assert(adds(int.max, 1, overflow) == int.min);
    assert(overflow);
    overflow = false;
    assert(adds(int.min, -1, overflow) == int.max);
    assert(overflow);
    assert(adds(0, 0, overflow) == 0);
    assert(overflow);                   // sticky
}

/// ditto
pragma(inline, true)
long adds(long x, long y, ref bool overflow)
{
    long r = cast(ulong)x + cast(ulong)y;
    if (x <  0 && y <  0 && r >= 0 ||
        x >= 0 && y >= 0 && r <  0)
        overflow = true;
    return r;
}

unittest
{
    bool overflow;
    assert(adds(2L, 3L, overflow) == 5);
    assert(!overflow);
    assert(adds(1L, long.max - 1, overflow) == long.max);
    assert(!overflow);
    assert(adds(long.min + 1, -1, overflow) == long.min);
    assert(!overflow);
    assert(adds(long.max, 1, overflow) == long.min);
    assert(overflow);
    overflow = false;
    assert(adds(long.min, -1, overflow) == long.max);
    assert(overflow);
    assert(adds(0L, 0L, overflow) == 0);
    assert(overflow);                   // sticky
}


/*******************************
 * Add two unsigned integers, checking for overflow (aka carry).
 *
 * The overflow is sticky, meaning a sequence of operations can
 * be done and overflow need only be checked at the end.
 * Params:
 *      x = left operand
 *      y = right operand
 *      overflow = set if an overflow occurs, is not affected otherwise
 * Returns:
 *      the sum
 */

pragma(inline, true)
uint addu(uint x, uint y, ref bool overflow)
{
    uint r = x + y;
    if (r < x || r < y)
        overflow = true;
    return r;
}

unittest
{
    bool overflow;
    assert(addu(2, 3, overflow) == 5);
    assert(!overflow);
    assert(addu(1, uint.max - 1, overflow) == uint.max);
    assert(!overflow);
    assert(addu(uint.min, -1, overflow) == uint.max);
    assert(!overflow);
    assert(addu(uint.max, 1, overflow) == uint.min);
    assert(overflow);
    overflow = false;
    assert(addu(uint.min + 1, -1, overflow) == uint.min);
    assert(overflow);
    assert(addu(0, 0, overflow) == 0);
    assert(overflow);                   // sticky
}

/// ditto
pragma(inline, true)
ulong addu(ulong x, ulong y, ref bool overflow)
{
    ulong r = x + y;
    if (r < x || r < y)
        overflow = true;
    return r;
}

unittest
{
    bool overflow;
    assert(addu(2L, 3L, overflow) == 5);
    assert(!overflow);
    assert(addu(1, ulong.max - 1, overflow) == ulong.max);
    assert(!overflow);
    assert(addu(ulong.min, -1L, overflow) == ulong.max);
    assert(!overflow);
    assert(addu(ulong.max, 1, overflow) == ulong.min);
    assert(overflow);
    overflow = false;
    assert(addu(ulong.min + 1, -1L, overflow) == ulong.min);
    assert(overflow);
    assert(addu(0L, 0L, overflow) == 0);
    assert(overflow);                   // sticky
}


/*******************************
 * Subtract two signed integers, checking for overflow.
 *
 * The overflow is sticky, meaning a sequence of operations can
 * be done and overflow need only be checked at the end.
 * Params:
 *      x = left operand
 *      y = right operand
 *      overflow = set if an overflow occurs, is not affected otherwise
 * Returns:
 *      the sum
 */

pragma(inline, true)
int subs(int x, int y, ref bool overflow)
{
    long r = cast(long)x - cast(long)y;
    if (r < int.min || r > int.max)
        overflow = true;
    return cast(int)r;
}

unittest
{
    bool overflow;
    assert(subs(2, -3, overflow) == 5);
    assert(!overflow);
    assert(subs(1, -int.max + 1, overflow) == int.max);
    assert(!overflow);
    assert(subs(int.min + 1, 1, overflow) == int.min);
    assert(!overflow);
    assert(subs(int.max, -1, overflow) == int.min);
    assert(overflow);
    overflow = false;
    assert(subs(int.min, 1, overflow) == int.max);
    assert(overflow);
    assert(subs(0, 0, overflow) == 0);
    assert(overflow);                   // sticky
}

/// ditto
pragma(inline, true)
long subs(long x, long y, ref bool overflow)
{
    long r = cast(ulong)x - cast(ulong)y;
    if (x <  0 && y >= 0 && r >= 0 ||
        x >= 0 && y <  0 && (r <  0 || y == long.min))
        overflow = true;
    return r;
}

unittest
{
    bool overflow;
    assert(subs(2L, -3L, overflow) == 5);
    assert(!overflow);
    assert(subs(1L, -long.max + 1, overflow) == long.max);
    assert(!overflow);
    assert(subs(long.min + 1, 1, overflow) == long.min);
    assert(!overflow);
    assert(subs(-1L, long.min, overflow) == long.max);
    assert(!overflow);
    assert(subs(long.max, -1, overflow) == long.min);
    assert(overflow);
    overflow = false;
    assert(subs(long.min, 1, overflow) == long.max);
    assert(overflow);
    assert(subs(0L, 0L, overflow) == 0);
    assert(overflow);                   // sticky
}

/*******************************
 * Subtract two unsigned integers, checking for overflow (aka borrow).
 *
 * The overflow is sticky, meaning a sequence of operations can
 * be done and overflow need only be checked at the end.
 * Params:
 *      x = left operand
 *      y = right operand
 *      overflow = set if an overflow occurs, is not affected otherwise
 * Returns:
 *      the sum
 */

pragma(inline, true)
uint subu(uint x, uint y, ref bool overflow)
{
    if (x < y)
        overflow = true;
    return x - y;
}

unittest
{
    bool overflow;
    assert(subu(3, 2, overflow) == 1);
    assert(!overflow);
    assert(subu(uint.max, 1, overflow) == uint.max - 1);
    assert(!overflow);
    assert(subu(1, 1, overflow) == uint.min);
    assert(!overflow);
    assert(subu(0, 1, overflow) == uint.max);
    assert(overflow);
    overflow = false;
    assert(subu(uint.max - 1, uint.max, overflow) == uint.max);
    assert(overflow);
    assert(subu(0, 0, overflow) == 0);
    assert(overflow);                   // sticky
}


/// ditto
pragma(inline, true)
ulong subu(ulong x, ulong y, ref bool overflow)
{
    if (x < y)
        overflow = true;
    return x - y;
}

unittest
{
    bool overflow;
    assert(subu(3UL, 2UL, overflow) == 1);
    assert(!overflow);
    assert(subu(ulong.max, 1, overflow) == ulong.max - 1);
    assert(!overflow);
    assert(subu(1UL, 1UL, overflow) == ulong.min);
    assert(!overflow);
    assert(subu(0UL, 1UL, overflow) == ulong.max);
    assert(overflow);
    overflow = false;
    assert(subu(ulong.max - 1, ulong.max, overflow) == ulong.max);
    assert(overflow);
    assert(subu(0UL, 0UL, overflow) == 0);
    assert(overflow);                   // sticky
}


/***********************************************
 * Negate an integer.
 *
 * Params:
 *      x = operand
 *      overflow = set if x cannot be negated, is not affected otherwise
 * Returns:
 *      the negation of x
 */

pragma(inline, true)
int negs(int x, ref bool overflow)
{
    if (x == int.min)
        overflow = true;
    return -x;
}

unittest
{
    bool overflow;
    assert(negs(0, overflow) == -0);
    assert(!overflow);
    assert(negs(1234, overflow) == -1234);
    assert(!overflow);
    assert(negs(-5678, overflow) == 5678);
    assert(!overflow);
    assert(negs(int.min, overflow) == -int.min);
    assert(overflow);
    assert(negs(0, overflow) == -0);
    assert(overflow);                   // sticky
}

/// ditto
pragma(inline, true)
long negs(long x, ref bool overflow)
{
    if (x == long.min)
        overflow = true;
    return -x;
}

unittest
{
    bool overflow;
    assert(negs(0L, overflow) == -0);
    assert(!overflow);
    assert(negs(1234L, overflow) == -1234);
    assert(!overflow);
    assert(negs(-5678L, overflow) == 5678);
    assert(!overflow);
    assert(negs(long.min, overflow) == -long.min);
    assert(overflow);
    assert(negs(0L, overflow) == -0);
    assert(overflow);                   // sticky
}


/*******************************
 * Multiply two signed integers, checking for overflow.
 *
 * The overflow is sticky, meaning a sequence of operations can
 * be done and overflow need only be checked at the end.
 * Params:
 *      x = left operand
 *      y = right operand
 *      overflow = set if an overflow occurs, is not affected otherwise
 * Returns:
 *      the sum
 */

pragma(inline, true)
int muls(int x, int y, ref bool overflow)
{
    long r = cast(long)x * cast(long)y;
    if (r < int.min || r > int.max)
        overflow = true;
    return cast(int)r;
}

unittest
{
    bool overflow;
    assert(muls(2, 3, overflow) == 6);
    assert(!overflow);
    assert(muls(-200, 300, overflow) == -60_000);
    assert(!overflow);
    assert(muls(1, int.max, overflow) == int.max);
    assert(!overflow);
    assert(muls(int.min, 1, overflow) == int.min);
    assert(!overflow);
    assert(muls(int.max, 2, overflow) == (int.max * 2));
    assert(overflow);
    overflow = false;
    assert(muls(int.min, -1, overflow) == int.min);
    assert(overflow);
    assert(muls(0, 0, overflow) == 0);
    assert(overflow);                   // sticky
}

/// ditto
pragma(inline, true)
long muls(long x, long y, ref bool overflow)
{
    long r = cast(ulong)x * cast(ulong)y;
    enum not0or1 = ~1L;
    if((x & not0or1) && ((r == y)? r : (r / x) != y))
        overflow = true;
    return r;
}

unittest
{
    bool overflow;
    assert(muls(2L, 3L, overflow) == 6);
    assert(!overflow);
    assert(muls(-200L, 300L, overflow) == -60_000);
    assert(!overflow);
    assert(muls(1, long.max, overflow) == long.max);
    assert(!overflow);
    assert(muls(long.min, 1L, overflow) == long.min);
    assert(!overflow);
    assert(muls(long.max, 2L, overflow) == (long.max * 2));
    assert(overflow);
    overflow = false;
    assert(muls(-1L, long.min, overflow) == long.min);
    assert(overflow);
    overflow = false;
    assert(muls(long.min, -1L, overflow) == long.min);
    assert(overflow);
    assert(muls(0L, 0L, overflow) == 0);
    assert(overflow);                   // sticky
}


/*******************************
 * Multiply two unsigned integers, checking for overflow (aka carry).
 *
 * The overflow is sticky, meaning a sequence of operations can
 * be done and overflow need only be checked at the end.
 * Params:
 *      x = left operand
 *      y = right operand
 *      overflow = set if an overflow occurs, is not affected otherwise
 * Returns:
 *      the sum
 */

pragma(inline, true)
uint mulu(uint x, uint y, ref bool overflow)
{
    ulong r = ulong(x) * ulong(y);
    if (r > uint.max)
        overflow = true;
    return cast(uint)r;
}

unittest
{
    void test(uint x, uint y, uint r, bool overflow) @nogc nothrow
    {
        bool o;
        assert(mulu(x, y, o) == r);
        assert(o == overflow);
    }
    test(2, 3, 6, false);
    test(1, uint.max, uint.max, false);
    test(0, 1, 0, false);
    test(0, uint.max, 0, false);
    test(uint.max, 2, 2 * uint.max, true);
    test(1 << 16, 1U << 16, 0, true);

    bool overflow = true;
    assert(mulu(0, 0, overflow) == 0);
    assert(overflow);                   // sticky
}

/// ditto
pragma(inline, true)
ulong mulu(ulong x, ulong y, ref bool overflow)
{
    ulong r = x * y;
    if (x && (r / x) != y)
        overflow = true;
    return r;
}

unittest
{
    void test(ulong x, ulong y, ulong r, bool overflow) @nogc nothrow
    {
        bool o;
        assert(mulu(x, y, o) == r);
        assert(o == overflow);
    }
    test(2, 3, 6, false);
    test(1, ulong.max, ulong.max, false);
    test(0, 1, 0, false);
    test(0, ulong.max, 0, false);
    test(ulong.max, 2, 2 * ulong.max, true);
    test(1UL << 32, 1UL << 32, 0, true);

    bool overflow = true;
    assert(mulu(0UL, 0UL, overflow) == 0);
    assert(overflow);                   // sticky
}
