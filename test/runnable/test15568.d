// REQUIRED_ARGS: -unittest -main -O
// https://issues.dlang.org/show_bug.cgi?id=15568

import std.algorithm;
import std.array;

class A
{
    B foo(C c, D[] ds, bool f)
    in
    {
        assert(c !is null);
    }
    body
    {
        D[] ds2 = ds.filter!(a => c).array;

        return new B(ds2, f);
    }
}

class B
{
    this(D[], bool)
    {
    }
}

class C
{
}

struct D
{
}

unittest
{
    auto a = new A;
    C c = new C;

    a.foo(c, null, false);
}

