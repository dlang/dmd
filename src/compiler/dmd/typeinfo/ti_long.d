
// long

module rt.typeinfo.ti_long;

class TypeInfo_l : TypeInfo
{
    string toString() { return "long"; }

    hash_t getHash(in void* p)
    {
        return *cast(uint *)p + (cast(uint *)p)[1];
    }

    equals_t equals(in void* p1, in void* p2)
    {
        return *cast(long *)p1 == *cast(long *)p2;
    }

    int compare(in void* p1, in void* p2)
    {
        if (*cast(long *)p1 < *cast(long *)p2)
            return -1;
        else if (*cast(long *)p1 > *cast(long *)p2)
            return 1;
        return 0;
    }

    size_t tsize()
    {
        return long.sizeof;
    }

    void swap(void *p1, void *p2)
    {
        long t;

        t = *cast(long *)p1;
        *cast(long *)p1 = *cast(long *)p2;
        *cast(long *)p2 = t;
    }
}
