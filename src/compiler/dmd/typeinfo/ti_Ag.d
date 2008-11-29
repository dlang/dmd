
module typeinfo.ti_Ag;

private import util.string;
private import core.stdc.string;

// byte[]

class TypeInfo_Ag : TypeInfo
{
    override string toString() { return "byte[]"; }

    override hash_t getHash(in void* p)
    {   byte[] s = *cast(byte[]*)p;
        size_t len = s.length;
        byte *str = s.ptr;
        hash_t hash = 0;

        while (1)
        {
            switch (len)
            {
                case 0:
                    return hash;

                case 1:
                    hash *= 9;
                    hash += *cast(ubyte *)str;
                    return hash;

                case 2:
                    hash *= 9;
                    hash += *cast(ushort *)str;
                    return hash;

                case 3:
                    hash *= 9;
                    hash += (*cast(ushort *)str << 8) +
                            (cast(ubyte *)str)[2];
                    return hash;

                default:
                    hash *= 9;
                    hash += *cast(uint *)str;
                    str += 4;
                    len -= 4;
                    break;
            }
        }

        return hash;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        byte[] s1 = *cast(byte[]*)p1;
        byte[] s2 = *cast(byte[]*)p2;

        return s1.length == s2.length &&
               memcmp(cast(byte *)s1, cast(byte *)s2, s1.length) == 0;
    }

    override int compare(in void* p1, in void* p2)
    {
        byte[] s1 = *cast(byte[]*)p1;
        byte[] s2 = *cast(byte[]*)p2;
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

    override size_t tsize()
    {
        return (byte[]).sizeof;
    }

    override uint flags()
    {
        return 1;
    }

    override TypeInfo next()
    {
        return typeid(byte);
    }
}


// ubyte[]

class TypeInfo_Ah : TypeInfo_Ag
{
    override string toString() { return "ubyte[]"; }

    override int compare(in void* p1, in void* p2)
    {
        char[] s1 = *cast(char[]*)p1;
        char[] s2 = *cast(char[]*)p2;

        return dstrcmp(s1, s2);
    }

    override TypeInfo next()
    {
        return typeid(ubyte);
    }
}

// void[]

class TypeInfo_Av : TypeInfo_Ah
{
    override string toString() { return "void[]"; }

    override TypeInfo next()
    {
        return typeid(void);
    }
}

// bool[]

class TypeInfo_Ab : TypeInfo_Ah
{
    override string toString() { return "bool[]"; }

    override TypeInfo next()
    {
        return typeid(bool);
    }
}

// char[]

class TypeInfo_Aa : TypeInfo_Ag
{
    override string toString() { return "char[]"; }

    override hash_t getHash(in void* p)
    {   char[] s = *cast(char[]*)p;
        hash_t hash = 0;

version (all)
{
        foreach (char c; s)
            hash = hash * 11 + c;
}
else
{
        size_t len = s.length;
        char *str = s;

        while (1)
        {
            switch (len)
            {
                case 0:
                    return hash;

                case 1:
                    hash *= 9;
                    hash += *cast(ubyte *)str;
                    return hash;

                case 2:
                    hash *= 9;
                    hash += *cast(ushort *)str;
                    return hash;

                case 3:
                    hash *= 9;
                    hash += (*cast(ushort *)str << 8) +
                            (cast(ubyte *)str)[2];
                    return hash;

                default:
                    hash *= 9;
                    hash += *cast(uint *)str;
                    str += 4;
                    len -= 4;
                    break;
            }
        }
}
        return hash;
    }

    override TypeInfo next()
    {
        return typeid(char);
    }
}
