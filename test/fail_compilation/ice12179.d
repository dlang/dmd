/*
TEST_OUTPUT:
---
fail_compilation/ice12179.d(25): Error: array operation a[] + a[] without assignment not implemented
fail_compilation/ice12179.d(26): Error: array operation a[] - a[] without assignment not implemented
fail_compilation/ice12179.d(27): Error: array operation a[] * a[] without assignment not implemented
fail_compilation/ice12179.d(28): Error: array operation a[] / a[] without assignment not implemented
fail_compilation/ice12179.d(29): Error: array operation a[] % a[] without assignment not implemented
fail_compilation/ice12179.d(30): Error: array operation a[] ^ a[] without assignment not implemented
fail_compilation/ice12179.d(31): Error: array operation a[] & a[] without assignment not implemented
fail_compilation/ice12179.d(32): Error: array operation a[] | a[] without assignment not implemented
fail_compilation/ice12179.d(33): Error: array operation a[] ^^ 10 without assignment not implemented
fail_compilation/ice12179.d(34): Error: array operation -a[] without assignment not implemented
fail_compilation/ice12179.d(35): Error: array operation ~a[] without assignment not implemented
fail_compilation/ice12179.d(40): Error: array operation [1] + a[] without assignment not implemented
fail_compilation/ice12179.d(41): Error: array operation [1] + a[] without assignment not implemented
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
fail_compilation/ice12179.d(55): Error: array operation -a[] without assignment not implemented
fail_compilation/ice12179.d(57): Error: array operation (-a[])[0..4] without assignment not implemented
---
*/
float[] f12769(float[] a)
{
    if (a.length < 4)
        return -a[];
    else
        return (-a[])[0..4];
}
