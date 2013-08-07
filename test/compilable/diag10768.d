// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
compilable/diag10768.d(36): Deprecation: overriding base class function without using override attribute is deprecated (diag10768.Foo.frop overrides diag10768.Frop.frop)
---
*/

struct CirBuff(T)
{
    import std.traits: isArray;
    CirBuff!T opAssign(R)(R) if (isArray!R)
    {}

    T[] toArray()
    {
        T[] ret; //  = new T[this.length];
        return ret;
    }
    alias toArray this;
}

class Bar(T=int)
{
    CirBuff!T _bar;
}

class Once
{
    Bar!Foo _foobar;
}

class Foo : Frop
{
    // override
    public int frop() { return 1; }
}

class Frop
{
    public int frop() { return 0; }
}
