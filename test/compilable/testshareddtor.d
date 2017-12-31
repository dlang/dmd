// PERMUTE_ARGS:

/***************************************************/
// Tests calling unshared dtors from shared objects.
// See issues:
// https://issues.dlang.org/show_bug.cgi?id=12004
// https://issues.dlang.org/show_bug.cgi?id=13174

struct B12004
{
    ~this() {}
}

struct C12004
{
    shared B12004 b;
}

class D12004
{
    ~this() {}
}

class E12004
{
    shared D12004 d;

    this(shared D12004 d) { this.d = d; }
}

void test12004()
{
    C12004(shared(B12004)());
    new E12004(new shared(D12004)());
}
