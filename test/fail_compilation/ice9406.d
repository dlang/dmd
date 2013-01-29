/*
TEST_OUTPUT:
---
fail_compilation/ice9406.d(15): Error: mixin ice9406.S.t1().Mixin!() cannot resolve forward reference
fail_compilation/ice9406.d(22): Error: expression has no value
---
*/

mixin template Mixin() { }

struct S
{
    template t1()
    {
        mixin Mixin t1;
    }
}

void main()
{
    S s1;
    s1.t1!();
}
