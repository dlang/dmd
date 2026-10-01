// https://github.com/dlang/dmd/issues/23919

struct S
{
    this(ref S) @system {}
}

void take(S s) {}

@safe void f(S s)
{
    enum ok = __traits(compiles, take(s));
    static assert(!ok);
}

struct T
{
    this(ref T) {}
}

void takeT(T t) {}

@nogc void g(T t)
{
    enum ok = __traits(compiles, takeT(t));
    static assert(!ok);
}
