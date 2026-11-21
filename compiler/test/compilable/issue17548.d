mixin template T()
{
    void f() {}
}

mixin T t0;
mixin T;

struct A
{
    mixin T t;
    mixin T;

    void g()
    {
        f();
        t.f();
    }
}

void main()
{
    A a;
    a.g();
    f();
    t0.f();
}
