
// short

module rt.typeinfo.ti_short;

class TypeInfo_s : TypeInfo
{
    string toString() { return "short"; }

    hash_t getHash(in void* p)
    {
        return *cast(short *)p;
    }

    equals_t equals(in void* p1, in void* p2)
    {
        return *cast(short *)p1 == *cast(short *)p2;
    }

    int compare(in void* p1, in void* p2)
    {
        return *cast(short *)p1 - *cast(short *)p2;
    }

    size_t tsize()
    {
        return short.sizeof;
    }

    void swap(void *p1, void *p2)
    {
        short t;

        t = *cast(short *)p1;
        *cast(short *)p1 = *cast(short *)p2;
        *cast(short *)p2 = t;
    }
}
