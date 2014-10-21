
/**********************************************
 * This module implements integral arithmetic primitives that check
 * for out-of-range results.
 * This is a translation to C++ of D's core.checkedint
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
 * Source:    https://github.com/D-Programming-Language/dmd/blob/master/src/root/port.c
 */

#include <assert.h>

#include "checkedint.h"

#ifdef __DMC__
#undef UINT64_MAX
#define UINT64_MAX      18446744073709551615ULL
#undef UINT32_MAX
#define UINT32_MAX      4294967295U
#endif



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

int adds(int x, int y, bool& overflow)
{
    int64_t r = (int64_t)x + (int64_t)y;
    if (r < INT32_MIN || r > INT32_MAX)
        overflow = true;
    return (int)r;
}

#ifdef DEBUG
void unittest1()
{
    bool overflow = false;
    assert(adds(2, 3, overflow) == 5);
    assert(!overflow);
    assert(adds(1, INT32_MAX - 1, overflow) == INT32_MAX);
    assert(!overflow);
    assert(adds(INT32_MIN + 1, -1, overflow) == INT32_MIN);
    assert(!overflow);
    assert(adds(INT32_MAX, 1, overflow) == INT32_MIN);
    assert(overflow);
    overflow = false;
    assert(adds(INT32_MIN, -1, overflow) == INT32_MAX);
    assert(overflow);
    assert(adds(0, 0, overflow) == 0);
    assert(overflow);                   // sticky
}
#endif

/// ditto
int64_t adds(int64_t x, int64_t y, bool& overflow)
{
    int64_t r = (uint64_t)x + (uint64_t)y;
    if (x <  0 && y <  0 && r >= 0 ||
        x >= 0 && y >= 0 && r <  0)
        overflow = true;
    return r;
}

#ifdef DEBUG
void unittest2()
{
    bool overflow = false;
    assert(adds((int64_t)2, (int64_t)3, overflow) == 5);
    assert(!overflow);
    assert(adds((int64_t)1, INT64_MAX - 1, overflow) == INT64_MAX);
    assert(!overflow);
    assert(adds(INT64_MIN + 1, (int64_t)-1, overflow) == INT64_MIN);
    assert(!overflow);
    assert(adds(INT64_MAX, (int64_t)1, overflow) == INT64_MIN);
    assert(overflow);
    overflow = false;
    assert(adds(INT64_MIN, (int64_t)-1, overflow) == INT64_MAX);
    assert(overflow);
    assert(adds((int64_t)0, (int64_t)0, overflow) == 0);
    assert(overflow);                   // sticky
}
#endif


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

unsigned addu(unsigned x, unsigned y, bool& overflow)
{
    unsigned r = x + y;
    if (r < x || r < y)
        overflow = true;
    return r;
}

#ifdef DEBUG
void unittest3()
{
    bool overflow = false;
    assert(addu(2U, 3U, overflow) == 5);
    assert(!overflow);
    assert(addu(1U, UINT32_MAX - 1U, overflow) == UINT32_MAX);
    assert(!overflow);
    assert(addu(0U, -1U, overflow) == UINT32_MAX);
    assert(!overflow);
    assert(addu(UINT32_MAX, 1U, overflow) == 0);
    assert(overflow);
    overflow = false;
    assert(addu(0U + 1U, -1U, overflow) == 0);
    assert(overflow);
    assert(addu(0U, 0U, overflow) == 0);
    assert(overflow);                   // sticky
}
#endif

/// ditto
uint64_t addu(uint64_t x, uint64_t y, bool& overflow)
{
    uint64_t r = x + y;
    if (r < x || r < y)
        overflow = true;
    return r;
}

#ifdef DEBUG
void unittest4()
{
    bool overflow = false;
    assert(addu((uint64_t)2, (uint64_t)3, overflow) == 5);
    assert(!overflow);
    assert(addu((uint64_t)1, UINT64_MAX - 1, overflow) == UINT64_MAX);
    assert(!overflow);
    assert(addu((uint64_t)0, (uint64_t)-1, overflow) == UINT64_MAX);
    assert(!overflow);
    assert(addu(UINT64_MAX, (uint64_t)1, overflow) == 0);
    assert(overflow);
    overflow = false;
    assert(addu((uint64_t)0 + 1, (uint64_t)-1, overflow) == 0);
    assert(overflow);
    assert(addu((uint64_t)0, (uint64_t)0, overflow) == 0);
    assert(overflow);                   // sticky
}
#endif


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

int subs(int x, int y, bool& overflow)
{
    int64_t r = (int64_t)x - (int64_t)y;
    if (r < INT32_MIN || r > INT32_MAX)
        overflow = true;
    return (int)r;
}

#ifdef DEBUG
void unittest5()
{
    bool overflow = false;
    assert(subs(2, -3, overflow) == 5);
    assert(!overflow);
    assert(subs(1, -INT32_MAX + 1, overflow) == INT32_MAX);
    assert(!overflow);
    assert(subs(INT32_MIN + 1, 1, overflow) == INT32_MIN);
    assert(!overflow);
    assert(subs(INT32_MAX, -1, overflow) == INT32_MIN);
    assert(overflow);
    overflow = false;
    assert(subs(INT32_MIN, 1, overflow) == INT32_MAX);
    assert(overflow);
    assert(subs(0, 0, overflow) == 0);
    assert(overflow);                   // sticky
}
#endif

/// ditto
int64_t subs(int64_t x, int64_t y, bool& overflow)
{
    int64_t r = (uint64_t)x - (uint64_t)y;
    if (x <  0 && y >= 0 && r >= 0 ||
        x >= 0 && y <  0 && r <  0 ||
        y == INT64_MIN)
        overflow = true;
    return r;
}

#ifdef DEBUG
void unittest6()
{
    bool overflow = false;
    assert(subs((int64_t)2, (int64_t)-3, overflow) == 5);
    assert(!overflow);
    assert(subs((int64_t)1, -INT64_MAX + (int64_t)1, overflow) == INT64_MAX);
    assert(!overflow);
    assert(subs(INT64_MIN + 1, (int64_t)1, overflow) == INT64_MIN);
    assert(!overflow);
    assert(subs(INT64_MAX, (int64_t)-1, overflow) == INT64_MIN);
    assert(overflow);
    overflow = false;
    assert(subs(INT64_MIN, (int64_t)1, overflow) == INT64_MAX);
    assert(overflow);
    assert(subs((int64_t)0, (int64_t)0, overflow) == 0);
    assert(overflow);                   // sticky
}
#endif

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

unsigned subu(unsigned x, unsigned y, bool& overflow)
{
    if (x < y)
        overflow = true;
    return x - y;
}

#ifdef DEBUG
void unittest7()
{
    bool overflow = false;
    assert(subu(3U, 2U, overflow) == 1);
    assert(!overflow);
    assert(subu(UINT32_MAX, 1U, overflow) == UINT32_MAX - 1);
    assert(!overflow);
    assert(subu(1U, 1U, overflow) == 0);
    assert(!overflow);
    assert(subu(0U, 1U, overflow) == UINT32_MAX);
    assert(overflow);
    overflow = false;
    assert(subu(UINT32_MAX - 1U, UINT32_MAX, overflow) == UINT32_MAX);
    assert(overflow);
    assert(subu(0U, 0U, overflow) == 0);
    assert(overflow);                   // sticky
}
#endif


/// ditto
uint64_t subu(uint64_t x, uint64_t y, bool& overflow)
{
    if (x < y)
        overflow = true;
    return x - y;
}

#ifdef DEBUG
void unittest8()
{
    bool overflow = false;
    assert(subu((uint64_t)3, (uint64_t)2, overflow) == 1);
    assert(!overflow);
    assert(subu(UINT64_MAX, (uint64_t)1, overflow) == UINT64_MAX - 1);
    assert(!overflow);
    assert(subu((uint64_t)1, (uint64_t)1, overflow) == 0);
    assert(!overflow);
    assert(subu((uint64_t)0, (uint64_t)1, overflow) == UINT64_MAX);
    assert(overflow);
    overflow = false;
    assert(subu(UINT64_MAX - 1, UINT64_MAX, overflow) == UINT64_MAX);
    assert(overflow);
    assert(subu((uint64_t)0, (uint64_t)0, overflow) == 0);
    assert(overflow);                   // sticky
}
#endif


/***********************************************
 * Negate an integer.
 *
 * Params:
 *      x = operand
 *      overflow = set if x cannot be negated, is not affected otherwise
 * Returns:
 *      the negation of x
 */

int negs(int x, bool& overflow)
{
    if (x == (int)INT32_MIN)
        overflow = true;
    return -x;
}

#ifdef DEBUG
void unittest9()
{
    bool overflow = false;
    assert(negs(0, overflow) == -0);
    assert(!overflow);
    assert(negs(1234, overflow) == -1234);
    assert(!overflow);
    assert(negs(-5678, overflow) == 5678);
    assert(!overflow);
    assert(negs((int)INT32_MIN, overflow) == -INT32_MIN);
    assert(overflow);
    assert(negs(0, overflow) == -0);
    assert(overflow);                   // sticky
}
#endif

/// ditto
int64_t negs(int64_t x, bool& overflow)
{
    if (x == INT64_MIN)
        overflow = true;
    return -x;
}

#ifdef DEBUG
void unittest10()
{
    bool overflow = false;
    assert(negs((int64_t)0, overflow) == -0);
    assert(!overflow);
    assert(negs((int64_t)1234, overflow) == -1234);
    assert(!overflow);
    assert(negs((int64_t)-5678, overflow) == 5678);
    assert(!overflow);
    assert(negs(INT64_MIN, overflow) == -INT64_MIN);
    assert(overflow);
    assert(negs((int64_t)0, overflow) == -0);
    assert(overflow);                   // sticky
}
#endif


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

int muls(int x, int y, bool& overflow)
{
    int64_t r = (int64_t)x * (int64_t)y;
    if (r < INT32_MIN || r > INT32_MAX)
        overflow = true;
    return (int)r;
}

#ifdef DEBUG
void unittest11()
{
    bool overflow = false;
    assert(muls(2, 3, overflow) == 6);
    assert(!overflow);
    assert(muls(-200, 300, overflow) == -60000);
    assert(!overflow);
    assert(muls(1, INT32_MAX, overflow) == INT32_MAX);
    assert(!overflow);
    assert(muls(INT32_MIN, 1, overflow) == INT32_MIN);
    assert(!overflow);
    assert(muls(INT32_MAX, 2, overflow) == (INT32_MAX * 2));
    assert(overflow);
    overflow = false;
    assert(muls(INT32_MIN, -1, overflow) == INT32_MIN);
    assert(overflow);
    assert(muls(0, 0, overflow) == 0);
    assert(overflow);                   // sticky
}
#endif

/// ditto
int64_t muls(int64_t x, int64_t y, bool& overflow)
{
    int64_t r = (uint64_t)x * (uint64_t)y;
    if (x && (r / x) != y)
        overflow = true;
    return r;
}

#ifdef DEBUG
void unittest12()
{
    bool overflow = false;
    assert(muls((int64_t)2, (int64_t)3, overflow) == 6);
    assert(!overflow);
    assert(muls((int64_t)-200, (int64_t)300, overflow) == -60000);
    assert(!overflow);
    assert(muls((int64_t)1, INT64_MAX, overflow) == INT64_MAX);
    assert(!overflow);
    assert(muls(INT64_MIN, (int64_t)1, overflow) == INT64_MIN);
    assert(!overflow);
    assert(muls(INT64_MAX, (int64_t)2, overflow) == (INT64_MAX * 2));
    assert(overflow);
    overflow = false;
    assert(muls(INT64_MIN, (int64_t)-1, overflow) == INT64_MIN);
    assert(overflow);
    assert(muls((int64_t)0, (int64_t)0, overflow) == 0);
    assert(overflow);                   // sticky
}
#endif


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

unsigned mulu(unsigned x, unsigned y, bool& overflow)
{
    unsigned r = x * y;
    if (r && (r < x || r < y))
        overflow = true;
    return r;
}

#ifdef DEBUG
void unittest13()
{
    bool overflow = false;
    assert(mulu(2U, 3U, overflow) == 6);
    assert(!overflow);
    assert(mulu(1U, UINT32_MAX, overflow) == UINT32_MAX);
    assert(!overflow);
    assert(mulu(0U, 1U, overflow) == 0);
    assert(!overflow);
    assert(mulu(UINT32_MAX, 2U, overflow) == (unsigned)(UINT32_MAX * 2));
    assert(overflow);
    overflow = false;
    assert(mulu(0U, -1U, overflow) == 0);
    assert(!overflow);
    overflow = true;
    assert(mulu(0U, 0U, overflow) == 0);
    assert(overflow);                   // sticky
}
#endif

/// ditto
uint64_t mulu(uint64_t x, uint64_t y, bool& overflow)
{
    uint64_t r = x * y;
    if (r && (r < x || r < y))
        overflow = true;
    return r;
}

#ifdef DEBUG
void unittest14()
{
    bool overflow = false;
    assert(mulu((uint64_t)2, (uint64_t)3, overflow) == 6);
    assert(!overflow);
    assert(mulu(1, UINT64_MAX, overflow) == UINT64_MAX);
    assert(!overflow);
    assert(mulu((uint64_t)0, 1, overflow) == 0);
    assert(!overflow);
    assert(mulu(UINT64_MAX, 2, overflow) == (UINT64_MAX * 2));
    assert(overflow);
    overflow = false;
    assert(mulu((uint64_t)0, -1, overflow) == 0);
    assert(!overflow);
    overflow = true;
    assert(mulu((uint64_t)0, (uint64_t)0, overflow) == 0);
    assert(overflow);                   // sticky
}
#endif

#ifdef DEBUG
struct CheckedintUnittest
{
    CheckedintUnittest()
    {
        unittest1();
        unittest2();
        unittest3();
        unittest4();
        unittest5();
        unittest6();
        unittest7();
        unittest8();
        unittest9();
        unittest10();
        unittest11();
        unittest12();
        unittest13();
    }
};

static CheckedintUnittest unittest;
#endif

//void main() { }
