/**
 * Implementation of array copy support routines.
 *
 * Copyright: Copyright Digital Mars 2004 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2004 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.arraycat;

private
{
    import core.stdc.string;
    debug import core.stdc.stdio;
}

extern (C):

byte[] _d_arraycopy(size_t size, byte[] from, byte[] to)
{
    debug printf("f = %p,%d, t = %p,%d, size = %d\n",
                 from.ptr, from.length, to.ptr, to.length, size);

    if (to.length != from.length)
    {
        throw new Exception("lengths don't match for array copy");
    }
    else if (to.ptr + to.length * size <= from.ptr ||
             from.ptr + from.length * size <= to.ptr)
    {
        memcpy(to.ptr, from.ptr, to.length * size);
    }
    else
    {
        throw new Exception("overlapping array copy");
    }
    return to;
}
