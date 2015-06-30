/**
 * Implementation of array copy support routines.
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
module rt.arraycat;

private
{
    import core.stdc.string;
    import rt.util.array;
    debug(PRINTF) import core.stdc.stdio;
}

extern (C) @trusted nothrow:

void[] _d_arraycopy(size_t size, void[] from, void[] to)
{
    debug(PRINTF) printf("f = %p,%d, t = %p,%d, size = %d\n",
                 from.ptr, from.length, to.ptr, to.length, size);

    enforceRawArraysConformable("copy", size, from, to);
    memcpy(to.ptr, from.ptr, to.length * size);
    return to;
}
