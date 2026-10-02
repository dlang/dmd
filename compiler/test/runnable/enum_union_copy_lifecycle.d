struct Resource
{
    int id;
    static int liveCount = 0;
    static int copyCount = 0;

    this(int id)
    {
        this.id = id;
        liveCount++;
    }

    this(ref return scope typeof(this) rhs)
    {
        this.id = rhs.id;
        liveCount++;
        copyCount++;
    }

    ~this()
    {
        liveCount--;
    }
}

enum union Holder
{
    case Item(Resource);
    case Empty();
}

void passByValue(Holder h)
{
    assert(Resource.liveCount == 2);
}

void main()
{
    {
        Holder h1 = Holder.Item(Resource(42));
        assert(Resource.liveCount == 1);
        assert(Resource.copyCount == 1); // 1 copy into the factory function payload

        passByValue(h1);
        assert(Resource.liveCount == 1);
        assert(Resource.copyCount == 2); // 1 copy for passByValue

        Holder h2 = h1;
        assert(Resource.liveCount == 2);
        assert(Resource.copyCount == 3); // 1 copy for h2 = h1
    }
    assert(Resource.liveCount == 0); // Both instances cleanly destructed
}
