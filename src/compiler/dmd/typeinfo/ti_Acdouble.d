/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt>Boost License 1.0</a>.
 * Authors:   Walter Bright
 *
 *          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_Acdouble;

private import rt.typeinfo.ti_cdouble;

// cdouble[]

class TypeInfo_Ar : TypeInfo
{
    override string toString() { return "cdouble[]"; }

    override hash_t getHash(in void* p)
    {   cdouble[] s = *cast(cdouble[]*)p;
        size_t len = s.length;
        cdouble *str = s.ptr;
        hash_t hash = 0;

        while (len)
        {
            hash *= 9;
            hash += (cast(uint *)str)[0];
            hash += (cast(uint *)str)[1];
            hash += (cast(uint *)str)[2];
            hash += (cast(uint *)str)[3];
            str++;
            len--;
        }

        return hash;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        cdouble[] s1 = *cast(cdouble[]*)p1;
        cdouble[] s2 = *cast(cdouble[]*)p2;
        size_t len = s1.length;

        if (len != s2.length)
            return false;
        for (size_t u = 0; u < len; u++)
        {
            if (!TypeInfo_r._equals(s1[u], s2[u]))
                return false;
        }
        return true;
    }

    override int compare(in void* p1, in void* p2)
    {
        cdouble[] s1 = *cast(cdouble[]*)p1;
        cdouble[] s2 = *cast(cdouble[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int c = TypeInfo_r._compare(s1[u], s2[u]);
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
        return (cdouble[]).sizeof;
    }

    override uint flags()
    {
        return 1;
    }

    override TypeInfo next()
    {
        return typeid(cdouble);
    }
}
