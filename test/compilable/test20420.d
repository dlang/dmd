// REQUIRED_ARGS: -inline

// https://issues.dlang.org/show_bug.cgi?id=20420

struct S { ~this() @system; }

class C
{
    this(S, int) {}
}

int i() @system;

C create()
{
    return new C(S(), i());
}

auto test()
{
    auto c = create();
}
