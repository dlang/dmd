/*
TEST_OUTPUT:
---
fail_compilation/diag13333.d(35): Error: template instance `VariantN!(maxSize!(S), T)` recursive template expansion
    alias Algebraic = VariantN!(maxSize!T, T);
                      ^
fail_compilation/diag13333.d(35): Error: template instance `diag13333.maxSize!(S)` error instantiating
    alias Algebraic = VariantN!(maxSize!T, T);
                                ^
fail_compilation/diag13333.d(40):        instantiated from here: `Algebraic!(S)`
    alias A = Algebraic!S;
              ^
---
*/

template maxSize(T...)
{
    static if (T.length == 1)
    {
        enum size_t maxSize = T[0].sizeof;
    }
    else
    {
        enum size_t maxSize = T[0].sizeof >= maxSize!(T[1 .. $])
            ? T[0].sizeof : maxSize!(T[1 .. $]);
    }
}

struct VariantN(size_t maxDataSize, AllowedTypesX...)
{
}

template Algebraic(T...)
{
    alias Algebraic = VariantN!(maxSize!T, T);
}

struct DummyScope
{
    alias A = Algebraic!S;

    static struct S     // <- class
    {
        A entity;
    }
}
