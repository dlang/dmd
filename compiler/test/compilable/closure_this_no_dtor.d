/**
 * Test that capturing `this` of a struct without destructor in a closure is allowed.
 */

struct S
{
    int x;

    void foo()
    {
        auto dg = () { return this; }; // OK: no destructor
    }
}

void main()
{
    S s;
    s.foo();
}
