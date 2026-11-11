// https://github.com/dlang/dmd/issues/24276
extern (C) struct S { }
extern (C) struct E { S s; }

version (CRuntime_Microsoft)
    static assert(S.sizeof == 4);
else
    static assert(S.sizeof == 0);

static assert(S.alignof == 1);

S s;
__gshared S gs;

extern (C++) struct T { }

static assert(T.sizeof == 1);
static assert(T.alignof == 1);

void main()
{
    static if (S.sizeof == 0)
    {
        S[] x = new S[5];
        assert(x.length == 5);
        x ~= S();
        assert(x.length == 6);
        assert((x ~ S()).length == 7);
        x.length = 2;
        x.length = 3;
        assert(x.length == 3);
        assert(x.capacity == size_t.max);
        assert(x.reserve(10) == size_t.max);
        x.assumeSafeAppend();
        assert((cast(E[]) x).length == 3);
    }
}
