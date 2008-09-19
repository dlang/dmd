
// real

module rt.typeinfo.ti_real;

class TypeInfo_e : TypeInfo
{
    string toString() { return "real"; }

    hash_t getHash(in void* p)
    {
        return (cast(uint *)p)[0] + (cast(uint *)p)[1] + (cast(ushort *)p)[4];
    }

    static int _equals(real f1, real f2)
    {
        return f1 == f2 ||
                (f1 !<>= f1 && f2 !<>= f2);
    }

    static int _compare(real d1, real d2)
    {
        if (d1 !<>= d2)         // if either are NaN
        {
            if (d1 !<>= d1)
            {   if (d2 !<>= d2)
                    return 0;
                return -1;
            }
            return 1;
        }
        return (d1 == d2) ? 0 : ((d1 < d2) ? -1 : 1);
    }

    equals_t equals(in void* p1, in void* p2)
    {
        return _equals(*cast(real *)p1, *cast(real *)p2);
    }

    int compare(in void* p1, in void* p2)
    {
        return _compare(*cast(real *)p1, *cast(real *)p2);
    }

    size_t tsize()
    {
        return real.sizeof;
    }

    void swap(void *p1, void *p2)
    {
        real t;

        t = *cast(real *)p1;
        *cast(real *)p1 = *cast(real *)p2;
        *cast(real *)p2 = t;
    }

    void[] init()
    {   static real r;

        return (cast(real *)&r)[0 .. 1];
    }
}
