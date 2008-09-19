
// cfloat

module rt.typeinfo.ti_cfloat;

class TypeInfo_q : TypeInfo
{
    string toString() { return "cfloat"; }

    hash_t getHash(in void* p)
    {
        return (cast(uint *)p)[0] + (cast(uint *)p)[1];
    }

    static int _equals(cfloat f1, cfloat f2)
    {
        return f1 == f2;
    }

    static int _compare(cfloat f1, cfloat f2)
    {   int result;

        if (f1.re < f2.re)
            result = -1;
        else if (f1.re > f2.re)
            result = 1;
        else if (f1.im < f2.im)
            result = -1;
        else if (f1.im > f2.im)
            result = 1;
        else
            result = 0;
        return result;
    }

    equals_t equals(in void* p1, in void* p2)
    {
        return _equals(*cast(cfloat *)p1, *cast(cfloat *)p2);
    }

    int compare(in void* p1, in void* p2)
    {
        return _compare(*cast(cfloat *)p1, *cast(cfloat *)p2);
    }

    size_t tsize()
    {
        return cfloat.sizeof;
    }

    void swap(void *p1, void *p2)
    {
        cfloat t;

        t = *cast(cfloat *)p1;
        *cast(cfloat *)p1 = *cast(cfloat *)p2;
        *cast(cfloat *)p2 = t;
    }

    void[] init()
    {   static cfloat r;

        return (cast(cfloat *)&r)[0 .. 1];
    }
}
