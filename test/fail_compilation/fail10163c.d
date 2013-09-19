/*
TEST_OUTPUT:
---
fail_compilation/fail10163c.d(17): Error: variable fail10163c.U.s1 missing initializer in static constructor
fail_compilation/fail10163c.d(18): Error: variable fail10163c.U.s2 missing initializer in static constructor
fail_compilation/fail10163c.d(20): Error: variable fail10163c.U.arr1 missing initializer in static constructor
fail_compilation/fail10163c.d(21): Error: variable fail10163c.U.arr2 missing initializer in static constructor
---
*/

struct S { @disable this(); this(int) { } }

struct U
{
    static:

    S s1;
    S s2;
    S s3;
    void[1] arr1;
    void[2] arr2;
    void[3] arr3;

    static this()
    {
        s3 = S(3);
        arr3 = [cast(byte)0];
    }
}
