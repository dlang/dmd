
// byte

module rt.typeinfo.ti_byte;

class TypeInfo_g : TypeInfo
{
    string toString() { return "byte"; }

    hash_t getHash(in void* p)
    {
        return *cast(byte *)p;
    }

    equals_t equals(in void* p1, in void* p2)
    {
        return *cast(byte *)p1 == *cast(byte *)p2;
    }

    int compare(in void* p1, in void* p2)
    {
        return *cast(byte *)p1 - *cast(byte *)p2;
    }

    size_t tsize()
    {
        return byte.sizeof;
    }

    void swap(void *p1, void *p2)
    {
        byte t;

        t = *cast(byte *)p1;
        *cast(byte *)p1 = *cast(byte *)p2;
        *cast(byte *)p2 = t;
    }
}
