
module rt.typeinfo.ti_char;

class TypeInfo_a : TypeInfo
{
    string toString() { return "char"; }

    hash_t getHash(in void* p)
    {
        return *cast(char *)p;
    }

    equals_t equals(in void* p1, in void* p2)
    {
        return *cast(char *)p1 == *cast(char *)p2;
    }

    int compare(in void* p1, in void* p2)
    {
        return *cast(char *)p1 - *cast(char *)p2;
    }

    size_t tsize()
    {
        return char.sizeof;
    }

    void swap(void *p1, void *p2)
    {
        char t;

        t = *cast(char *)p1;
        *cast(char *)p1 = *cast(char *)p2;
        *cast(char *)p2 = t;
    }

    void[] init()
    {   static char c;

        return (cast(char *)&c)[0 .. 1];
    }
}
