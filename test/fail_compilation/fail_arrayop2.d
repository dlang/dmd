// REQUIRED_ARGS: -o-

/*
TEST_OUTPUT:
---
fail_compilation/fail_arrayop2.d(12): Error: array operation [1, 2, 3] - [1, 2, 3] without destination memory not allowed
fail_compilation/fail_arrayop2.d(15): Error: invalid array operation "a" - "b" (possible missing [])
---
*/
void test2603() // Issue 2603 - ICE(cgcs.c) on subtracting string literals
{
    auto c1 = [1,2,3] - [1,2,3];

    // this variation is wrong code on D2, ICE ..\ztc\cgcs.c 358 on D1.
    string c2 = "a" - "b";
}

/*
TEST_OUTPUT:
---
fail_compilation/fail_arrayop2.d(37): Error: array operation -a[] without destination memory not allowed (possible missing [])
fail_compilation/fail_arrayop2.d(38): Error: array operation ~a[] without destination memory not allowed (possible missing [])
fail_compilation/fail_arrayop2.d(40): Error: array operation a[] + a[] without destination memory not allowed (possible missing [])
fail_compilation/fail_arrayop2.d(41): Error: array operation a[] - a[] without destination memory not allowed (possible missing [])
fail_compilation/fail_arrayop2.d(42): Error: array operation a[] * a[] without destination memory not allowed (possible missing [])
fail_compilation/fail_arrayop2.d(43): Error: array operation a[] / a[] without destination memory not allowed (possible missing [])
fail_compilation/fail_arrayop2.d(44): Error: array operation a[] % a[] without destination memory not allowed (possible missing [])
fail_compilation/fail_arrayop2.d(45): Error: array operation a[] ^ a[] without destination memory not allowed (possible missing [])
fail_compilation/fail_arrayop2.d(46): Error: array operation a[] & a[] without destination memory not allowed (possible missing [])
fail_compilation/fail_arrayop2.d(47): Error: array operation a[] | a[] without destination memory not allowed (possible missing [])
fail_compilation/fail_arrayop2.d(48): Error: array operation a[] ^^ a[] without destination memory not allowed (possible missing [])
---
*/
void test9459()
{
    int[] a = [1, 2, 3];
    a = -a[];
    a = ~a[];

    a = a[] + a[];
    a = a[] - a[];
    a = a[] * a[];
    a = a[] / a[];
    a = a[] % a[];
    a = a[] ^ a[];
    a = a[] & a[];
    a = a[] | a[];
    a = a[] ^^ a[];
}

/*
TEST_OUTPUT:
---
fail_compilation/fail_arrayop2.d(74): Error: array operation a[] + a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(75): Error: array operation a[] - a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(76): Error: array operation a[] * a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(77): Error: array operation a[] / a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(78): Error: array operation a[] % a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(79): Error: array operation a[] ^ a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(80): Error: array operation a[] & a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(81): Error: array operation a[] | a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(82): Error: array operation a[] ^^ 10 without destination memory not allowed
fail_compilation/fail_arrayop2.d(83): Error: array operation -a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(84): Error: array operation ~a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(89): Error: array operation [1] + a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(90): Error: array operation [1] + a[] without destination memory not allowed
---
*/
void test12179()
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

/*
TEST_OUTPUT:
---
fail_compilation/fail_arrayop2.d(104): Error: array operation h * y[] without destination memory not allowed
---
*/
void test12381()
{
    double[2] y;
    double h;

    double[2] temp1 = cast(double[2])(h * y[]);
}

/*
TEST_OUTPUT:
---
fail_compilation/fail_arrayop2.d(117): Error: array operation -a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(119): Error: array operation (-a[])[0..4] without destination memory not allowed
---
*/
float[] test12769(float[] a)
{
    if (a.length < 4)
        return -a[];
    else
        return (-a[])[0..4];
}

/*
TEST_OUTPUT:
---
fail_compilation/fail_arrayop2.d(136): Error: array operation a[] - a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(138): Error: array operation a[] - a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(139): Error: array operation a[] - a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(142): Error: array operation a[] - a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(144): Error: array operation a[] - a[] without destination memory not allowed
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

/*
TEST_OUTPUT:
---
fail_compilation/fail_arrayop2.d(159): Error: array operation a[] * a[] without destination memory not allowed
fail_compilation/fail_arrayop2.d(160): Error: array operation (a[] * a[])[0..1] without destination memory not allowed
fail_compilation/fail_arrayop2.d(163): Error: array operation a[] * a[] without destination memory not allowed (possible missing [])
fail_compilation/fail_arrayop2.d(164): Error: array operation (a[] * a[])[0..1] without destination memory not allowed (possible missing [])
---
*/
void test13497()
{
    int[1] a;
    auto b1 = (a[] * a[])[];
    auto b2 = (a[] * a[])[0..1];

    int[] c;
    c = (a[] * a[])[];
    c = (a[] * a[])[0..1];
}

/*
TEST_OUTPUT:
---
fail_compilation/fail_arrayop2.d(180): Error: array operation data[segmentId][28..29] & cast(ubyte)(1 << 0) without destination memory not allowed
---
*/
void test13910()
{
    ubyte[][] data;
    size_t segmentId;

    bool isGroup()
    {
        return !!((data[segmentId][28..29]) & (1 << 0));
    }
}
