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

/***************************************************/
// Struct member destructor can not be called from shared struct instance
// See https://issues.dlang.org/show_bug.cgi?id=8295.

struct A8295a
{
    char[] buf;

    this(size_t size)
    {
        buf = new char[size];
    }

    ~this()
    {
        buf = null;
    }
}

struct B8295a
{
    A8295a f;
}

shared B8295a test8295a;

/***************************************************/

struct A8295b
{
    int a;
}

struct B8295b
{
    A8295b f;

    ~this()
    {
    }
}

shared B8295b test8295b;
