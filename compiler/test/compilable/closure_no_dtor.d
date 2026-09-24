/**
 * Test that capturing a struct without destructor in a closure is allowed.
 */

struct NoDtor
{
    int x;
}

void main()
{
    NoDtor s;

    auto dg = () { return s; }; // OK: no destructor
}
