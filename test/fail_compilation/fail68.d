/*
TEST_OUTPUT:
---
fail_compilation/fail68.d(14): Error: can only initialize const member y inside constructor
---
*/

class C
{
    const int y;

    void foo()
    {
        y = 6;
    }

    this()
    {
        y = 7;
    }
}
