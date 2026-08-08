/**
 * Test that capturing a local struct without destructor in a closure is allowed.
 */

void main()
{
    struct Local
    {
        int x;
    }

    Local s;

    auto dg = () { return s; }; // OK: no destructor
}
