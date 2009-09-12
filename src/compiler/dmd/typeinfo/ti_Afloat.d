/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 *
 *          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_Afloat;

private import rt.typeinfo.ti_float;

// float[]

class TypeInfo_Af : TypeInfo
{
    override string toString() { return "float[]"; }

    override hash_t getHash(in void* p)
    {   float[] s = *cast(float[]*)p;
        size_t len = s.length;
        auto str = s.ptr;
        hash_t hash = 0;

        while (len)
        {
            hash *= 9;
            hash += *cast(uint *)str;
            str++;
            len--;
        }

        return hash;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        float[] s1 = *cast(float[]*)p1;
        float[] s2 = *cast(float[]*)p2;
        size_t len = s1.length;

        if (len != s2.length)
            return 0;
        for (size_t u = 0; u < len; u++)
        {
            if (!TypeInfo_f._equals(s1[u], s2[u]))
                return false;
        }
        return true;
    }

    override int compare(in void* p1, in void* p2)
    {
        float[] s1 = *cast(float[]*)p1;
        float[] s2 = *cast(float[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int c = TypeInfo_f._compare(s1[u], s2[u]);
            if (c)
                return c;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    override size_t tsize()
    {
        return (float[]).sizeof;
    }

    override uint flags()
    {
        return 1;
    }

    override TypeInfo next()
    {
        return typeid(float);
    }
}

// ifloat[]

class TypeInfo_Ao : TypeInfo_Af
{
    override string toString() { return "ifloat[]"; }

    override TypeInfo next()
    {
        return typeid(ifloat);
    }
}
