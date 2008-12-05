
// int

module rt.typeinfo.ti_int;

class TypeInfo_i : TypeInfo
{
    override string toString() { return "int"; }

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
        if (*cast(int*) p1 < *cast(int*) p2)
            return -1;
        else if (*cast(int*) p1 > *cast(int*) p2)
            return 1;
        return 0;
    }

    override size_t tsize()
    {
        return int.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        int t;

        t = *cast(int *)p1;
        *cast(int *)p1 = *cast(int *)p2;
        *cast(int *)p2 = t;
    }
}
