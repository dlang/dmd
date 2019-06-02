/*
TEST_OUTPUT:
---
fail_compilation/fail6856.d(30): Error: function `fail6856.EvenMoreDerived.foo` cannot have an in contract when overridden function `fail6856.Derived.foo` does not have an in contract
---
*/

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

class Derived : Base
{
    override void foo(int x)
    {
    }
}

class EvenMoreDerived : Derived
{
    override void foo(int x)
    in
    {
    }
    body
    {
    }
}
