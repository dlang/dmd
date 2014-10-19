/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_float;

// float

class TypeInfo_f : TypeInfo
{
    @trusted:
    pure:
    nothrow:

    static bool _equals(float f1, float f2)
    {
        return f1 == f2;
    }

    static int _compare(float d1, float d2)
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

    override string toString() const pure nothrow @safe { return "float"; }

    override size_t getHash(in void* p)
    {
        return *cast(uint *)p;
    }

    override bool equals(in void* p1, in void* p2)
    {
        return _equals(*cast(float *)p1, *cast(float *)p2);
    }

    override int compare(in void* p1, in void* p2)
    {
        return _compare(*cast(float *)p1, *cast(float *)p2);
    }

    override @property size_t tsize() nothrow pure
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

    override const(void)[] init() nothrow pure
    {
        static immutable float r;

        return (cast(float *)&r)[0 .. 1];
    }

    version (Windows)
    {
    }
    else version (X86_64)
    {
        // 2 means arg to function is passed in XMM registers
        override @property uint flags() nothrow pure const @safe { return 2; }
    }
}
