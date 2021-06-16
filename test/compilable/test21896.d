template Works(T)
{
    static if (is(T U == const U))
    {
        alias Works = U;
    }
}

template Fails(T)
{
    alias Fails = T;
    static if (is(T U == const U))
    {
        Fails = U;
    }
}

static assert(is(Works!(const int) == int));
static assert(is(Fails!(const int) == int));
