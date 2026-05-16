// https://github.com/dlang/dmd/issues/22769

int foo()() => 0;

void bar()
{
    cast(void) i"$(foo)";
}

struct OutBuffer
{
    void opOpAssign(string op, T...)(T args) {}
}

void qux()
{
    OutBuffer buf;
    buf ~= i"$(foo)";
}
