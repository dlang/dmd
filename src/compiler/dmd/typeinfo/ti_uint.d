
// uint

module typeinfo.ti_uint;

class TypeInfo_k : TypeInfo
{
    override string toString() { return "uint"; }

    override hash_t getHash(in void* p)
    {
        return *cast(uint *)p;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return *cast(uint *)p1 == *cast(uint *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        if (*cast(uint*) p1 < *cast(uint*) p2)
            return -1;
        else if (*cast(uint*) p1 > *cast(uint*) p2)
            return 1;
        return 0;
    }

    override size_t tsize()
    {
        return uint.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        int t;

        t = *cast(uint *)p1;
        *cast(uint *)p1 = *cast(uint *)p2;
        *cast(uint *)p2 = t;
    }
}
