
module rt.typeinfo.ti_Ashort;

private import stdc.string;

// short[]

class TypeInfo_As : TypeInfo
{
    string toString() { return "short[]"; }

    hash_t getHash(in void* p)
    {   short[] s = *cast(short[]*)p;
        size_t len = s.length;
        short *str = s.ptr;
        hash_t hash = 0;

        while (1)
        {
            switch (len)
            {
                case 0:
                    return hash;

                case 1:
                    hash *= 9;
                    hash += *cast(ushort *)str;
                    return hash;

                default:
                    hash *= 9;
                    hash += *cast(uint *)str;
                    str += 2;
                    len -= 2;
                    break;
            }
        }

        return hash;
    }

    equals_t equals(in void* p1, in void* p2)
    {
        short[] s1 = *cast(short[]*)p1;
        short[] s2 = *cast(short[]*)p2;

        return s1.length == s2.length &&
               memcmp(cast(void *)s1, cast(void *)s2, s1.length * short.sizeof) == 0;
    }

    int compare(in void* p1, in void* p2)
    {
        short[] s1 = *cast(short[]*)p1;
        short[] s2 = *cast(short[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int result = s1[u] - s2[u];
            if (result)
                return result;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    size_t tsize()
    {
        return (short[]).sizeof;
    }

    uint flags()
    {
        return 1;
    }

    TypeInfo next()
    {
        return typeid(short);
    }
}


// ushort[]

class TypeInfo_At : TypeInfo_As
{
    string toString() { return "ushort[]"; }

    int compare(in void* p1, in void* p2)
    {
        ushort[] s1 = *cast(ushort[]*)p1;
        ushort[] s2 = *cast(ushort[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int result = s1[u] - s2[u];
            if (result)
                return result;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    TypeInfo next()
    {
        return typeid(ushort);
    }
}

// wchar[]

class TypeInfo_Au : TypeInfo_At
{
    string toString() { return "wchar[]"; }

    TypeInfo next()
    {
        return typeid(wchar);
    }
}
