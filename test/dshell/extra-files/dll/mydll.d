module mydll;

export:

/// TODO: Accessing this variable causes a segfault on Arch
version (Windows) __gshared int saved_var;

int multiply10(int x)
{
    version (Windows) saved_var = x;

    return x * 10;
}

struct S
{
    int i;

    export int add(int j)
    {
        return i += j;
    }
}

interface I
{
    C foo(I);

    export static C create()
    {
        return new C();
    }
}

class C : I
{
    int x, y;

    export C foo(I i)
    {
        return cast(C) i;
    }
}
