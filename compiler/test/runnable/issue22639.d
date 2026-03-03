// REQUIRED_ARGS: -betterC

struct Arr(T, int CAPACITY)
{
    int count = 0;
    T[CAPACITY] items;
    int opApply(scope int delegate(T) dg)
    {
        int result;
        for (int i = 0; i < count; i++)
            if ((result = dg(items[i])) != 0)
                break;
        return result;
    }
}

struct Foo {}
struct Bar {
    Arr!(Foo*, 32) array;
    Foo* get()
    {
        foreach(Foo* it; array)
        {
            return it;
        }
        return null;
    }
}

Foo* foo;
Bar bar;
extern(C) void main()
{
    foo = bar.get();
}
