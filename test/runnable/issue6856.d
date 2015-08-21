module issue6856;

class Base
{
    void foo(int x)
    in
    {
        assert(false);
    }
    body
    {

    }
}


class Derived: Base
{
    override void foo(int x)
    in
    {
        assert(x > 5);
    }
    body
    {

    }
}


class EvenMoreDerived: Derived
{
    override void foo(int x)
    in
    {}
    body
    {

    }
}

void test1()
{
    auto derived = new EvenMoreDerived;
    derived.foo(2);
}

void main()
{
    test1();
}
