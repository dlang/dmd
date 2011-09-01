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
module rt.typeinfo.ti_AC;

// Object[]

class TypeInfo_AC : TypeInfo
{
    override hash_t getHash(in void* p)
    {   Object[] s = *cast(Object[]*)p;
        hash_t hash = 0;

        foreach (Object o; s)
        {
            if (o)
                hash += o.toHash();
        }
        return hash;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        Object[] s1 = *cast(Object[]*)p1;
        Object[] s2 = *cast(Object[]*)p2;

        if (s1.length == s2.length)
        {
            for (size_t u = 0; u < s1.length; u++)
            {   Object o1 = s1[u];
                Object o2 = s2[u];

                // Do not pass null's to Object.opEquals()
                if (o1 is o2 ||
                    (!(o1 is null) && !(o2 is null) && o1.opEquals(o2)))
                    continue;
                return false;
            }
            return true;
        }
        return false;
    }

    override int compare(in void* p1, in void* p2)
    {
        Object[] s1 = *cast(Object[]*)p1;
        Object[] s2 = *cast(Object[]*)p2;
        auto     c  = cast(sizediff_t)(s1.length - s2.length);
        if (c == 0)
        {
            for (size_t u = 0; u < s1.length; u++)
            {   Object o1 = s1[u];
                Object o2 = s2[u];

                if (o1 is o2)
                    continue;

                // Regard null references as always being "less than"
                if (o1)
                {
                    if (!o2)
                        return 1;
                    c = o1.opCmp(o2);
                    if (c == 0)
                        continue;
                    break;
                }
                else
                {
                    return -1;
                }
            }
        }
        return c < 0 ? -1 : c > 0 ? 1 : 0;
    }

    @property override size_t tsize() nothrow pure
    {
        return (Object[]).sizeof;
    }

    @property override uint flags() nothrow pure
    {
        return 1;
    }

    @property override TypeInfo next() nothrow pure
    {
        return typeid(Object);
    }

    @property override size_t talign() nothrow pure
    {
        return (Object[]).alignof;
    }

    version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2)
    {
        //arg1 = typeid(size_t);
        //arg2 = typeid(void*);
        return 0;
    }
}
