
// pointer

module typeinfo.ti_ptr;

class TypeInfo_P : TypeInfo
{
    override hash_t getHash(in void* p)
    {
        return cast(uint)*cast(void* *)p;
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return *cast(void* *)p1 == *cast(void* *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        auto c = *cast(void* *)p1 - *cast(void* *)p2;
        if (c < 0)
            return -1;
        else if (c > 0)
            return 1;
        return 0;
    }

    override size_t tsize()
    {
        return (void*).sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        void* t;

        t = *cast(void* *)p1;
        *cast(void* *)p1 = *cast(void* *)p2;
        *cast(void* *)p2 = t;
    }

    override uint flags()
    {
        return 1;
    }
}
