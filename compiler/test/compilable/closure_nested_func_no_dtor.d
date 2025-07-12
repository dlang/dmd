/**
 * Test that capturing a variable without destructor in a closure inside a nested function is allowed.
 */

struct S
{
    int x;
}

void main()
{
    S s;

    void nested()
    {
        auto dg = () { return s; }; // OK: no destructor
    }

    nested();
}
