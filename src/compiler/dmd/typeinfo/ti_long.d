
// long

module rt.typeinfo.ti_long;

class TypeInfo_l : TypeInfo
{
    override string toString() { return "long"; }

    override hash_t getHash(in void* p)
    {
        return *cast(uint *)p + (cast(uint *)p)[1];
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return *cast(long *)p1 == *cast(long *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        if (*cast(long *)p1 < *cast(long *)p2)
            return -1;
        else if (*cast(long *)p1 > *cast(long *)p2)
            return 1;
        return 0;
    }

    override size_t tsize()
    {
        return long.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        long t;

        t = *cast(long *)p1;
        *cast(long *)p1 = *cast(long *)p2;
        *cast(long *)p2 = t;
    }
}
