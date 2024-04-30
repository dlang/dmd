// https://issues.dlang.org/show_bug.cgi?id=21204

struct A
{
    this(ref A other) {}
}

struct B
{
    A a;
}

void example()
{
    B b1;
    B b2 = b1;
}
