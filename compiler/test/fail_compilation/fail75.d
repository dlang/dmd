/*
TEST_OUTPUT:
---
fail_compilation/fail75.d(15): Error: cannot append type `fail75.C` to type `C[1]`
        c ~= this;
          ^
---
*/

class C
{
    C[1] c;
    this()
    {
        c ~= this;
    }
}
