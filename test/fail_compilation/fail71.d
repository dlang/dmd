/*
TEST_OUTPUT:
---
fail_compilation/fail71.d(17): Error: can only initialize const member y inside constructor
---
*/

class C
{
    const int y;

    this()
    {
        C c = this;

        y = 7;
        c.y = 8;
    }
}
