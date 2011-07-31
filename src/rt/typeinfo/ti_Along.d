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
module rt.typeinfo.ti_Along;

private import core.stdc.string;
private import rt.util.hash;

// long[]

class TypeInfo_Al : TypeInfo
{
    override string toString() { return "long[]"; }

    override hash_t getHash(in void* p)
    {   long[] s = *cast(long[]*)p;
        return hashOf(s.ptr, s.length * long.sizeof);
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        long[] s1 = *cast(long[]*)p1;
        long[] s2 = *cast(long[]*)p2;

        return s1.length == s2.length &&
               memcmp(cast(void *)s1, cast(void *)s2, s1.length * long.sizeof) == 0;
    }

    override int compare(in void* p1, in void* p2)
    {
        long[] s1 = *cast(long[]*)p1;
        long[] s2 = *cast(long[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            if (s1[u] < s2[u])
                return -1;
            else if (s1[u] > s2[u])
                return 1;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    @property override size_t tsize() nothrow pure
    {
        return (long[]).sizeof;
    }

    @property override uint flags() nothrow pure
    {
        return 1;
    }

    @property override TypeInfo next() nothrow pure
    {
        return typeid(long);
    }

    @property override size_t talign() nothrow pure
    {
        return (long[]).alignof;
    }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        //arg1 = typeid(size_t);
        //arg2 = typeid(void*);
        return 0;
    }
}


// ulong[]

class TypeInfo_Am : TypeInfo_Al
{
    override string toString() { return "ulong[]"; }

    override int compare(in void* p1, in void* p2)
    {
        ulong[] s1 = *cast(ulong[]*)p1;
        ulong[] s2 = *cast(ulong[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            if (s1[u] < s2[u])
                return -1;
            else if (s1[u] > s2[u])
                return 1;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    @property override TypeInfo next() nothrow pure
    {
        return typeid(ulong);
    }
}
