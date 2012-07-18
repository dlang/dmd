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
module rt.typeinfo.ti_Acfloat;

private import rt.typeinfo.ti_cfloat;
private import rt.util.hash;

// cfloat[]

class TypeInfo_Aq : TypeInfo_Array
{
    override equals_t opEquals(Object o) { return TypeInfo.opEquals(o); }

    @trusted:
    const:
    pure:
    nothrow:

    override string toString() const pure nothrow @safe { return "cfloat[]"; }

    override hash_t getHash(in void* p)
    {
        cfloat[] s = *cast(cfloat[]*)p;
        return hashOf(s.ptr, s.length * cfloat.sizeof);
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        cfloat[] s1 = *cast(cfloat[]*)p1;
        cfloat[] s2 = *cast(cfloat[]*)p2;
        size_t len = s1.length;

        if (len != s2.length)
            return false;
        for (size_t u = 0; u < len; u++)
        {
            if (!TypeInfo_q._equals(s1[u], s2[u]))
                return false;
        }
        return true;
    }

    override int compare(in void* p1, in void* p2)
    {
        cfloat[] s1 = *cast(cfloat[]*)p1;
        cfloat[] s2 = *cast(cfloat[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int c = TypeInfo_q._compare(s1[u], s2[u]);
            if (c)
                return c;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    override @property const(TypeInfo) next() nothrow pure
    {
        return typeid(cfloat);
    }
}
