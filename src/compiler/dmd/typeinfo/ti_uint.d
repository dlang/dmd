
// uint

module rt.typeinfo.ti_uint;

class TypeInfo_k : TypeInfo
{
    string toString() { return "uint"; }

    hash_t getHash(in void* p)
    {
        return *cast(uint *)p;
    }

    equals_t equals(in void* p1, in void* p2)
    {
        return *cast(uint *)p1 == *cast(uint *)p2;
    }

    int compare(in void* p1, in void* p2)
    {
        if (*cast(uint*) p1 < *cast(uint*) p2)
            return -1;
        else if (*cast(uint*) p1 > *cast(uint*) p2)
            return 1;
        return 0;
    }

    size_t tsize()
    {
        return uint.sizeof;
    }

    void swap(void *p1, void *p2)
    {
        int t;

        t = *cast(uint *)p1;
        *cast(uint *)p1 = *cast(uint *)p2;
        *cast(uint *)p2 = t;
    }
}
