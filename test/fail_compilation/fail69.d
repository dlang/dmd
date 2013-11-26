/*
TEST_OUTPUT:
---
fail_compilation/fail69.d(14): Error: can only initialize static const member x inside static constructor
---
*/

class C
{
    static const int x;

    void foo()
    {
        x = 4;
    }

    static this()
    {
        x = 5;
    }
}
