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
        ptrdiff_t c;

        c = cast(ptrdiff_t)s1.length - cast(ptrdiff_t)s2.length;
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
                    {   c = 1;
                        break;
                    }
                    c = o1.opCmp(o2);
                    if (c)
                        break;
                }
                else
                {   c = -1;
                    break;
                }
            }
        }
        if (c < 0)
            c = -1;
        else if (c > 0)
            c = 1;
        return c;
    }

    override size_t tsize()
    {
        return (Object[]).sizeof;
    }

    override uint flags()
    {
        return 1;
    }

    override TypeInfo next()
    {
        return typeid(Object);
    }
}
