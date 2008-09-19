
// ushort

module rt.typeinfo.ti_ushort;

class TypeInfo_t : TypeInfo
{
    string toString() { return "ushort"; }

    hash_t getHash(in void* p)
    {
        return *cast(ushort *)p;
    }

    equals_t equals(in void* p1, in void* p2)
    {
        return *cast(ushort *)p1 == *cast(ushort *)p2;
    }

    int compare(in void* p1, in void* p2)
    {
        return *cast(ushort *)p1 - *cast(ushort *)p2;
    }

    size_t tsize()
    {
        return ushort.sizeof;
    }

    void swap(void *p1, void *p2)
    {
        ushort t;

        t = *cast(ushort *)p1;
        *cast(ushort *)p1 = *cast(ushort *)p2;
        *cast(ushort *)p2 = t;
    }
}
