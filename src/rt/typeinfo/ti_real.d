/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_real;

private import rt.util.hash;

// real

class TypeInfo_e : TypeInfo
{
    @trusted:
    pure:
    nothrow:

    static bool _equals(real f1, real f2)
    {
        return f1 == f2;
    }

    static int _compare(real d1, real d2)
    {
        if (d1 != d1 || d2 != d2)         // if either are NaN
        {
            if (d1 != d1)
            {
                if (d2 != d2)
                    return 0;
                return -1;
            }
            return 1;
        }
        return (d1 == d2) ? 0 : ((d1 < d2) ? -1 : 1);
    }

    const:

    override string toString() const pure nothrow @safe { return "real"; }

    override size_t getHash(in void* p)
    {
        return rt.util.hash.hashOf(p, real.sizeof);
    }

    override bool equals(in void* p1, in void* p2)
    {
        return _equals(*cast(real *)p1, *cast(real *)p2);
    }

    override int compare(in void* p1, in void* p2)
    {
        return _compare(*cast(real *)p1, *cast(real *)p2);
    }

    override @property size_t tsize() nothrow pure
    {
        return real.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        real t;

        t = *cast(real *)p1;
        *cast(real *)p1 = *cast(real *)p2;
        *cast(real *)p2 = t;
    }

    override const(void)[] init() nothrow pure
    {
        static immutable real r;

        return (cast(real *)&r)[0 .. 1];
    }

    override @property size_t talign() nothrow pure
    {
        return real.alignof;
    }
}
