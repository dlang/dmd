
// ulong

module rt.typeinfo.ti_ulong;

class TypeInfo_m : TypeInfo
{
    override string toString() { return "ulong"; }

    override hash_t getHash(in void* p)
    {
        return *cast(uint *)p + (cast(uint *)p)[1];
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return *cast(ulong *)p1 == *cast(ulong *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        if (*cast(ulong *)p1 < *cast(ulong *)p2)
            return -1;
        else if (*cast(ulong *)p1 > *cast(ulong *)p2)
            return 1;
        return 0;
    }

    override size_t tsize()
    {
        return ulong.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        ulong t;

        t = *cast(ulong *)p1;
        *cast(ulong *)p1 = *cast(ulong *)p2;
        *cast(ulong *)p2 = t;
    }
}
