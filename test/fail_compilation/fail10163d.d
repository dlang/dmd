/*
TEST_OUTPUT:
---
fail_compilation/fail10163d.d(12): Error: variable fail10163d.Temp!().arr1 missing initializer in static constructor
fail_compilation/fail10163d.d(13): Error: variable fail10163d.Temp!().arr2 missing initializer in static constructor
fail_compilation/fail10163d.d(24): Error: variable fail10163d.Temp!().s1 missing initializer in static constructor
fail_compilation/fail10163d.d(25): Error: variable fail10163d.Temp!().s2 missing initializer in static constructor
---
*/

template Temp() {
    void[1] arr1;
    void[2] arr2;
    void[3] arr3;

    static this()
    {
        arr3 = [cast(byte)0];
    }

    struct S { @disable this(); this(int) { } }
    struct T { this(int) { } }

    S s1;
    S s2;
    S s3;
    T t1;
    T t2;

    static this()
    {
        s3 = S(1);
        t2 = T(2);
    }
}

mixin Temp;
