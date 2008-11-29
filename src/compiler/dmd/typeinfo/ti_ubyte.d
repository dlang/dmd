
// ubyte

module typeinfo.ti_ubyte;

class TypeInfo_h : TypeInfo
{
    override string toString() { return "ubyte"; }

    override hash_t getHash(in void* p)
    {
        return *cast(ubyte *)p;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return *cast(ubyte *)p1 == *cast(ubyte *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        return *cast(ubyte *)p1 - *cast(ubyte *)p2;
    }

    override size_t tsize()
    {
        return ubyte.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        ubyte t;

        t = *cast(ubyte *)p1;
        *cast(ubyte *)p1 = *cast(ubyte *)p2;
        *cast(ubyte *)p2 = t;
    }
}

class TypeInfo_b : TypeInfo_h
{
    override string toString() { return "bool"; }
}
