
// ubyte

module rt.typeinfo.ti_ubyte;

class TypeInfo_h : TypeInfo
{
    string toString() { return "ubyte"; }

    hash_t getHash(in void* p)
    {
        return *cast(ubyte *)p;
    }

    equals_t equals(in void* p1, in void* p2)
    {
        return *cast(ubyte *)p1 == *cast(ubyte *)p2;
    }

    int compare(in void* p1, in void* p2)
    {
        return *cast(ubyte *)p1 - *cast(ubyte *)p2;
    }

    size_t tsize()
    {
        return ubyte.sizeof;
    }

    void swap(void *p1, void *p2)
    {
        ubyte t;

        t = *cast(ubyte *)p1;
        *cast(ubyte *)p1 = *cast(ubyte *)p2;
        *cast(ubyte *)p2 = t;
    }
}

class TypeInfo_b : TypeInfo_h
{
    string toString() { return "bool"; }
}
