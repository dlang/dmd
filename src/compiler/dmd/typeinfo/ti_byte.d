
// byte

module rt.typeinfo.ti_byte;

class TypeInfo_g : TypeInfo
{
    override string toString() { return "byte"; }

    override hash_t getHash(in void* p)
    {
        return *cast(byte *)p;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return *cast(byte *)p1 == *cast(byte *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        return *cast(byte *)p1 - *cast(byte *)p2;
    }

    override size_t tsize()
    {
        return byte.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        byte t;

        t = *cast(byte *)p1;
        *cast(byte *)p1 = *cast(byte *)p2;
        *cast(byte *)p2 = t;
    }
}
