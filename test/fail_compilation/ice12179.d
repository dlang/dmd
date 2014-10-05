/*
TEST_OUTPUT:
---
fail_compilation/ice12179.d(25): Error: array operation a[] + a[] without destination memory not allowed
fail_compilation/ice12179.d(26): Error: array operation a[] - a[] without destination memory not allowed
fail_compilation/ice12179.d(27): Error: array operation a[] * a[] without destination memory not allowed
fail_compilation/ice12179.d(28): Error: array operation a[] / a[] without destination memory not allowed
fail_compilation/ice12179.d(29): Error: array operation a[] % a[] without destination memory not allowed
fail_compilation/ice12179.d(30): Error: array operation a[] ^ a[] without destination memory not allowed
fail_compilation/ice12179.d(31): Error: array operation a[] & a[] without destination memory not allowed
fail_compilation/ice12179.d(32): Error: array operation a[] | a[] without destination memory not allowed
fail_compilation/ice12179.d(33): Error: array operation a[] ^^ 10 without destination memory not allowed
fail_compilation/ice12179.d(34): Error: array operation -a[] without destination memory not allowed
fail_compilation/ice12179.d(35): Error: array operation ~a[] without destination memory not allowed
fail_compilation/ice12179.d(40): Error: array operation [1] + a[] without destination memory not allowed
fail_compilation/ice12179.d(41): Error: array operation [1] + a[] without destination memory not allowed
---
*/

void main()
{
    void foo(int[]) {}
    int[1] a;

    foo(a[] + a[]);
    foo(a[] - a[]);
    foo(a[] * a[]);
    foo(a[] / a[]);
    foo(a[] % a[]);
    foo(a[] ^ a[]);
    foo(a[] & a[]);
    foo(a[] | a[]);
    foo(a[] ^^ 10);
    foo(-a[]);
    foo(~a[]);

    // from issue 11992
    int[]   arr1;
    int[][] arr2;
    arr1 ~= [1] + a[];         // NG
    arr2 ~= [1] + a[];         // NG
}

// from issue 12769
/*
TEST_OUTPUT:
---
fail_compilation/ice12179.d(55): Error: array operation -a[] without destination memory not allowed
fail_compilation/ice12179.d(57): Error: array operation (-a[])[0..4] without destination memory not allowed
---
*/
float[] f12769(float[] a)
{
    if (a.length < 4)
        return -a[];
    else
        return (-a[])[0..4];
}

/*
TEST_OUTPUT:
---
fail_compilation/ice12179.d(74): Error: array operation a[] - a[] without destination memory not allowed
fail_compilation/ice12179.d(76): Error: array operation a[] - a[] without destination memory not allowed
fail_compilation/ice12179.d(77): Error: array operation a[] - a[] without destination memory not allowed
fail_compilation/ice12179.d(80): Error: array operation a[] - a[] without destination memory not allowed
fail_compilation/ice12179.d(82): Error: array operation a[] - a[] without destination memory not allowed
---
*/
void test13208()
{
    int[] a;

    auto arr = [a[] - a[]][0];

    auto aa1 = [1 : a[] - a[]];
    auto aa2 = [a[] - a[] : 1];

    struct S { int[] a; }
    auto s = S(a[] - a[]);

    auto n = int(a[] - a[]);
}
