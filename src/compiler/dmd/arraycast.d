/*
 *  Copyright (C) 2004-2007 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, in both source and binary form, subject to the following
 *  restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

/*
 *  Modified by Sean Kelly for use with the D Runtime Project
 */

module rt.arraycast;

/******************************************
 * Runtime helper to convert dynamic array of one
 * type to dynamic array of another.
 * Adjusts the length of the array.
 * Throws exception if new length is not aligned.
 */

extern (C)

void[] _d_arraycast(size_t tsize, size_t fsize, void[] a)
{
    auto length = a.length;

    auto nbytes = length * fsize;
    if (nbytes % tsize != 0)
    {
    throw new Exception("array cast misalignment");
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
 * Throws exception if new length is not aligned.
 */

version (none)
{
extern (C)

void[] _d_arraycast_frombit(uint tsize, void[] a)
{
    uint length = a.length;

    if (length & 7)
    {
    throw new Exception("bit[] array cast misalignment");
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
