/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_float;

// float

class TypeInfo_f : TypeInfo
{
    override string toString() { return "float"; }

    override hash_t getHash(in void* p)
    {
        return *cast(uint *)p;
    }

    static equals_t _equals(float f1, float f2)
    {
        return f1 == f2 ||
                (f1 !<>= f1 && f2 !<>= f2);
    }

    static int _compare(float d1, float d2)
    {
        if (d1 !<>= d2)         // if either are NaN
        {
            if (d1 !<>= d1)
            {   if (d2 !<>= d2)
                    return 0;
                return -1;
            }
            return 1;
        }
        return (d1 == d2) ? 0 : ((d1 < d2) ? -1 : 1);
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return _equals(*cast(float *)p1, *cast(float *)p2);
    }

    override int compare(in void* p1, in void* p2)
    {
        return _compare(*cast(float *)p1, *cast(float *)p2);
    }

    @property override size_t tsize() nothrow pure
    {
        return float.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        float t;

        t = *cast(float *)p1;
        *cast(float *)p1 = *cast(float *)p2;
        *cast(float *)p2 = t;
    }

    override void[] init() nothrow pure
    {   static immutable float r;

        return (cast(float *)&r)[0 .. 1];
    }
}
