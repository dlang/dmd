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
module rt.typeinfo.ti_Areal;

private import rt.typeinfo.ti_real;
private import rt.util.hash;

// real[]

class TypeInfo_Ae : TypeInfo_Array
{
    override bool opEquals(Object o) { return TypeInfo.opEquals(o); }

    override string toString() const { return "real[]"; }

    override size_t getHash(in void* p) @trusted const
    {
        real[] s = *cast(real[]*)p;
        return rt.util.hash.hashOf(s.ptr, s.length * real.sizeof);
    }

    override bool equals(in void* p1, in void* p2) const
    {
        real[] s1 = *cast(real[]*)p1;
        real[] s2 = *cast(real[]*)p2;
        size_t len = s1.length;

        if (len != s2.length)
            return false;
        for (size_t u = 0; u < len; u++)
        {
            if (!TypeInfo_e._equals(s1[u], s2[u]))
                return false;
        }
        return true;
    }

    override int compare(in void* p1, in void* p2) const
    {
        real[] s1 = *cast(real[]*)p1;
        real[] s2 = *cast(real[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int c = TypeInfo_e._compare(s1[u], s2[u]);
            if (c)
                return c;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout)typeid(real);
    }
}

// ireal[]

class TypeInfo_Aj : TypeInfo_Ae
{
    override string toString() const { return "ireal[]"; }

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout)typeid(ireal);
    }
}
