/**
 * Test that capturing a class without destructor in a closure is allowed.
 */

class C
{
    int x;
}

void main()
{
    auto obj = new C();

    auto dg = () { return obj; }; // OK: no destructor
}
