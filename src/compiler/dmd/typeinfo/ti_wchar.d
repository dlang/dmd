
module typeinfo.ti_wchar;


class TypeInfo_u : TypeInfo
{
    override string toString() { return "wchar"; }

    override hash_t getHash(in void* p)
    {
        return *cast(wchar *)p;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return *cast(wchar *)p1 == *cast(wchar *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        return *cast(wchar *)p1 - *cast(wchar *)p2;
    }

    override size_t tsize()
    {
        return wchar.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        wchar t;

        t = *cast(wchar *)p1;
        *cast(wchar *)p1 = *cast(wchar *)p2;
        *cast(wchar *)p2 = t;
    }

    override void[] init()
    {   static wchar c;

        return (cast(wchar *)&c)[0 .. 1];
    }
}
