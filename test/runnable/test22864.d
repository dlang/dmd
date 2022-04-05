// https://issues.dlang.org/show_bug.cgi?id=22864

import core.stdc.stdlib;

public S* deserializeFull ()
{
    return &[ getS() ][0];
}

S getS () { throw new Exception("socket error"); }

struct S
{
    ~this ()
    {
        abort();
    }

    ubyte hash;
}

void foo ()
{
    try
    {
        auto v = deserializeFull();
        assert(0, "Exception not thrown?");
    }
    catch (Exception exc)
    {
        assert(exc.msg == "socket error");
    }
}

void main ()
{
    foo();
    import core.memory;
    GC.collect(); // Abort triggered from here
}
