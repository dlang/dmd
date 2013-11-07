/**
 * Implementation of array copy support routines.
 *
 * Copyright: Copyright Digital Mars 2004 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2004 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.arraycat;

private
{
    import core.stdc.string;
    import rt.util.string;
    debug(PRINTF) import core.stdc.stdio;
}

extern (C) @trusted nothrow:

byte[] _d_arraycopy(size_t size, byte[] from, byte[] to)
{
    debug(PRINTF) printf("f = %p,%d, t = %p,%d, size = %d\n",
                 from.ptr, from.length, to.ptr, to.length, size);

    if (to.length != from.length)
    {
        SizeStringBuff tmpBuff = void;
        string msg = "lengths don't match for array copy, "c;
        msg ~= to.length.sizeToTempString(tmpBuff);
        msg ~= " = ";
        msg ~= from.length.sizeToTempString(tmpBuff);
        throw new Error(msg);
    }
    else if (to.ptr + to.length * size <= from.ptr ||
             from.ptr + from.length * size <= to.ptr)
    {
        memcpy(to.ptr, from.ptr, to.length * size);
    }
    else
    {
        throw new Error("overlapping array copy");
    }
    return to;
}
