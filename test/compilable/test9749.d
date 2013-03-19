int foo(typeof(return) arg)
{
    static assert(is(typeof(arg) == int));
    return 0;
}

float bar()
{
    int foo(typeof(return) arg)
    {
        static assert(is(typeof(arg) == int));
        return 0;
    }

    return 1;
}

void hash(int[string] arg) { }

int doo(T)(typeof(return)[T] arg)
{
    hash(arg);
    return 1;
}

void main()
{
    doo!string(["a" : 1]);
}
