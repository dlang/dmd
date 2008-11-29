
// ushort

module typeinfo.ti_ushort;

class TypeInfo_t : TypeInfo
{
    override string toString() { return "ushort"; }

    override hash_t getHash(in void* p)
    {
        return *cast(ushort *)p;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return *cast(ushort *)p1 == *cast(ushort *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        return *cast(ushort *)p1 - *cast(ushort *)p2;
    }

    override size_t tsize()
    {
        return ushort.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        ushort t;

        t = *cast(ushort *)p1;
        *cast(ushort *)p1 = *cast(ushort *)p2;
        *cast(ushort *)p2 = t;
    }
}
