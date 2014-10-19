/**
 * Implementation of array cast support routines.
 *
 * Copyright: Copyright Digital Mars 2004 - 2010.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2004 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.arraycast;

/******************************************
 * Runtime helper to convert dynamic array of one
 * type to dynamic array of another.
 * Adjusts the length of the array.
 * Throws an error if new length is not aligned.
 */

extern (C)

@trusted nothrow
void[] _d_arraycast(size_t tsize, size_t fsize, void[] a)
{
    auto length = a.length;

    auto nbytes = length * fsize;
    if (nbytes % tsize != 0)
    {
        throw new Error("array cast misalignment");
    }
    length = nbytes / tsize;
    *cast(size_t *)&a = length; // jam new length
    return a;
}

unittest
{
    byte[int.sizeof * 3] b;
    int[] i;
    short[] s;

    i = cast(int[])b;
    assert(i.length == 3);

    s = cast(short[])b;
    assert(s.length == 6);

    s = cast(short[])i;
    assert(s.length == 6);
}

/******************************************
 * Runtime helper to convert dynamic array of bits
 * dynamic array of another.
 * Adjusts the length of the array.
 * Throws an error if new length is not aligned.
 */

version (none)
{
extern (C)

@trusted nothrow
void[] _d_arraycast_frombit(uint tsize, void[] a)
{
    uint length = a.length;

    if (length & 7)
    {
       throw new Error("bit[] array cast misalignment");
    }
    length /= 8 * tsize;
    *cast(size_t *)&a = length; // jam new length
    return a;
}

unittest
{
    version (D_Bits)
    {
    bit[int.sizeof * 3 * 8] b;
    int[] i;
    short[] s;

    i = cast(int[])b;
    assert(i.length == 3);

    s = cast(short[])b;
    assert(s.length == 6);
    }
}

}
