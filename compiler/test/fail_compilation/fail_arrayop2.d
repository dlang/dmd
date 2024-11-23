// REQUIRED_ARGS: -o-


/*
TEST_OUTPUT:
---
fail_compilation/fail_arrayop2.d(271): Error: array operation `[1, 2, 3] - [1, 2, 3]` without destination memory not allowed
    auto c1 = [1,2,3] - [1,2,3];
              ^
fail_compilation/fail_arrayop2.d(274): Error: invalid array operation `"a" - "b"` (possible missing [])
    string c2 = "a" - "b";
                ^
fail_compilation/fail_arrayop2.d(280): Error: array operation `-a[]` without destination memory not allowed (possible missing [])
    a = -a[];
        ^
fail_compilation/fail_arrayop2.d(281): Error: array operation `~a[]` without destination memory not allowed (possible missing [])
    a = ~a[];
        ^
fail_compilation/fail_arrayop2.d(283): Error: array operation `a[] + a[]` without destination memory not allowed (possible missing [])
    a = a[] + a[];
        ^
fail_compilation/fail_arrayop2.d(284): Error: array operation `a[] - a[]` without destination memory not allowed (possible missing [])
    a = a[] - a[];
        ^
fail_compilation/fail_arrayop2.d(285): Error: array operation `a[] * a[]` without destination memory not allowed (possible missing [])
    a = a[] * a[];
        ^
fail_compilation/fail_arrayop2.d(286): Error: array operation `a[] / a[]` without destination memory not allowed (possible missing [])
    a = a[] / a[];
        ^
fail_compilation/fail_arrayop2.d(287): Error: array operation `a[] % a[]` without destination memory not allowed (possible missing [])
    a = a[] % a[];
        ^
fail_compilation/fail_arrayop2.d(288): Error: array operation `a[] ^ a[]` without destination memory not allowed (possible missing [])
    a = a[] ^ a[];
        ^
fail_compilation/fail_arrayop2.d(289): Error: array operation `a[] & a[]` without destination memory not allowed (possible missing [])
    a = a[] & a[];
        ^
fail_compilation/fail_arrayop2.d(290): Error: array operation `a[] | a[]` without destination memory not allowed (possible missing [])
    a = a[] | a[];
        ^
fail_compilation/fail_arrayop2.d(291): Error: array operation `a[] ^^ a[]` without destination memory not allowed (possible missing [])
    a = a[] ^^ a[];
        ^
fail_compilation/fail_arrayop2.d(299): Error: array operation `a[] + a[]` without destination memory not allowed
    foo(a[] + a[]);
        ^
fail_compilation/fail_arrayop2.d(300): Error: array operation `a[] - a[]` without destination memory not allowed
    foo(a[] - a[]);
        ^
fail_compilation/fail_arrayop2.d(301): Error: array operation `a[] * a[]` without destination memory not allowed
    foo(a[] * a[]);
        ^
fail_compilation/fail_arrayop2.d(302): Error: array operation `a[] / a[]` without destination memory not allowed
    foo(a[] / a[]);
        ^
fail_compilation/fail_arrayop2.d(303): Error: array operation `a[] % a[]` without destination memory not allowed
    foo(a[] % a[]);
        ^
fail_compilation/fail_arrayop2.d(304): Error: array operation `a[] ^ a[]` without destination memory not allowed
    foo(a[] ^ a[]);
        ^
fail_compilation/fail_arrayop2.d(305): Error: array operation `a[] & a[]` without destination memory not allowed
    foo(a[] & a[]);
        ^
fail_compilation/fail_arrayop2.d(306): Error: array operation `a[] | a[]` without destination memory not allowed
    foo(a[] | a[]);
        ^
fail_compilation/fail_arrayop2.d(307): Error: array operation `a[] ^^ 10` without destination memory not allowed
    foo(a[] ^^ 10);
        ^
fail_compilation/fail_arrayop2.d(308): Error: array operation `-a[]` without destination memory not allowed
    foo(-a[]);
        ^
fail_compilation/fail_arrayop2.d(309): Error: array operation `~a[]` without destination memory not allowed
    foo(~a[]);
        ^
fail_compilation/fail_arrayop2.d(314): Error: array operation `[1] + a[]` without destination memory not allowed
    arr1 ~= [1] + a[];         // NG
            ^
fail_compilation/fail_arrayop2.d(315): Error: array operation `[1] + a[]` without destination memory not allowed
    arr2 ~= [1] + a[];         // NG
            ^
fail_compilation/fail_arrayop2.d(323): Error: array operation `h * y[]` without destination memory not allowed
    double[2] temp1 = cast(double[2])(h * y[]);
                                      ^
fail_compilation/fail_arrayop2.d(329): Error: array operation `-a[]` without destination memory not allowed
        return -a[];
               ^
fail_compilation/fail_arrayop2.d(331): Error: array operation `(-a[])[0..4]` without destination memory not allowed
        return (-a[])[0..4];
                     ^
fail_compilation/fail_arrayop2.d(338): Error: array operation `a[] - a[]` without destination memory not allowed
    auto arr = [a[] - a[]][0];
                ^
fail_compilation/fail_arrayop2.d(340): Error: array operation `a[] - a[]` without destination memory not allowed
    auto aa1 = [1 : a[] - a[]];
                    ^
fail_compilation/fail_arrayop2.d(341): Error: array operation `a[] - a[]` without destination memory not allowed
    auto aa2 = [a[] - a[] : 1];
                ^
fail_compilation/fail_arrayop2.d(344): Error: array operation `a[] - a[]` without destination memory not allowed
    auto s = S(a[] - a[]);
               ^
fail_compilation/fail_arrayop2.d(346): Error: array operation `a[] - a[]` without destination memory not allowed
    auto n = int(a[] - a[]);
                 ^
fail_compilation/fail_arrayop2.d(352): Error: array operation `a[] * a[]` without destination memory not allowed
    auto b1 = (a[] * a[])[];
               ^
fail_compilation/fail_arrayop2.d(353): Error: array operation `(a[] * a[])[0..1]` without destination memory not allowed
    auto b2 = (a[] * a[])[0..1];
                         ^
fail_compilation/fail_arrayop2.d(356): Error: array operation `a[] * a[]` without destination memory not allowed (possible missing [])
    c = (a[] * a[])[];
         ^
fail_compilation/fail_arrayop2.d(357): Error: array operation `(a[] * a[])[0..1]` without destination memory not allowed (possible missing [])
    c = (a[] * a[])[0..1];
                   ^
fail_compilation/fail_arrayop2.d(367): Error: array operation `data[segmentId][28..29] & cast(ubyte)(1 << 0)` without destination memory not allowed
        return !!((data[segmentId][28..29]) & (1 << 0));
                  ^
fail_compilation/fail_arrayop2.d(374): Error: array operation `a[] + 1` without destination memory not allowed
    int[] b = (a[] + 1) ~ a[] * 2;
               ^
fail_compilation/fail_arrayop2.d(374): Error: array operation `a[] * 2` without destination memory not allowed
    int[] b = (a[] + 1) ~ a[] * 2;
                          ^
fail_compilation/fail_arrayop2.d(386): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = [[1] * 6]; }     // ArrayLiteralExp
                ^
fail_compilation/fail_arrayop2.d(387): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = [[1] * 6 :
                ^
fail_compilation/fail_arrayop2.d(388): Error: array operation `[1] * 6` without destination memory not allowed
                [1] * 6]; }     // AssocArrayLiteralExp
                ^
fail_compilation/fail_arrayop2.d(392): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = S([1] * 6); }
                 ^
fail_compilation/fail_arrayop2.d(395): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = new S([1] * 6); }
                     ^
fail_compilation/fail_arrayop2.d(404): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = ([1] * 6, 1); }
                ^
fail_compilation/fail_arrayop2.d(407): Error: array operation `[1] * 6` without destination memory not allowed
    assert([1] * 6,
           ^
fail_compilation/fail_arrayop2.d(408): Error: array operation `"abc"[] + '\x01'` without destination memory not allowed
           cast(char)1 + "abc"[]);
           ^
fail_compilation/fail_arrayop2.d(411): Error: array operation `[1] * 6` without destination memory not allowed
    f([1] * 6);
      ^
fail_compilation/fail_arrayop2.d(414): Error: cannot take address of expression `([1] * 6)[0..2]` because it is not an lvalue
    { auto r = &(([1] * 6)[0..2]); }
                          ^
fail_compilation/fail_arrayop2.d(417): Error: can only `*` a pointer, not a `int[]`
    { auto r = *([1] * 6); }
               ^
fail_compilation/fail_arrayop2.d(420): Error: the `delete` keyword is obsolete
    delete ([1] * 6);
    ^
fail_compilation/fail_arrayop2.d(420):        use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead
fail_compilation/fail_arrayop2.d(423): Error: array operation `da[] * 6` without destination memory not allowed
    { auto r = (6 * da[]).length; }
                ^
fail_compilation/fail_arrayop2.d(426): Error: array operation `da[] * 6` without destination memory not allowed
    { auto x1 = (da[] * 6)[1]; }
                 ^
fail_compilation/fail_arrayop2.d(429): Error: cannot modify expression `[1] * 6` because it is not an lvalue
    ([1] * 6)++;
     ^
fail_compilation/fail_arrayop2.d(430): Error: array operation `[1] * 6` without destination memory not allowed
    --([1] * 6);
       ^
fail_compilation/fail_arrayop2.d(433): Error: cannot modify expression `[1] * 6` because it is not an lvalue
    ([1] * 6) = 10;
     ^
fail_compilation/fail_arrayop2.d(434): Error: cannot modify expression `([1] * 6)[]` because it is not an lvalue
    ([1] * 6)[] = 10;
     ^
fail_compilation/fail_arrayop2.d(437): Error: array operation `[1] * 6` without destination memory not allowed
    ([1] * 6) += 1;
     ^
fail_compilation/fail_arrayop2.d(438): Error: array operation `[1] * 6` without destination memory not allowed
    ([1] * 6)[] *= 2;
     ^
fail_compilation/fail_arrayop2.d(439): Error: array operation `[1] * 6` without destination memory not allowed
    ([1] * 6)[] ^^= 3;
     ^
fail_compilation/fail_arrayop2.d(442): Error: cannot modify expression `[1] * 6` because it is not an lvalue
    ([1] * 6) ~= 1;
     ^
fail_compilation/fail_arrayop2.d(443): Error: cannot modify expression `[1] * 6` because it is not an lvalue
    ([1] * 6)[] ~= 2;
     ^
fail_compilation/fail_arrayop2.d(446): Error: `[1] * 6` is not of integral type, it is a `int[]`
    { auto r = ([1] * 6) << 1; }
                ^
fail_compilation/fail_arrayop2.d(447): Error: `[1] * 6` is not of integral type, it is a `int[]`
    { auto r = ([1] * 6) >> 1; }
                ^
fail_compilation/fail_arrayop2.d(448): Error: `[1] * 6` is not of integral type, it is a `int[]`
    { auto r = ([1] * 6) >>> 1; }
                ^
fail_compilation/fail_arrayop2.d(451): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = sa[0..5] && [1] * 6; }
                           ^
fail_compilation/fail_arrayop2.d(452): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = sa[0..5] || [1] * 6; }
                           ^
fail_compilation/fail_arrayop2.d(455): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = sa[0..5] <= [1] * 6; }
                           ^
fail_compilation/fail_arrayop2.d(456): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = sa[0..5] == [1] * 6; }
                           ^
fail_compilation/fail_arrayop2.d(457): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = sa[0..5] is [1] * 6; }
                           ^
fail_compilation/fail_arrayop2.d(460): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = [1] * 6 ? [1] * 6 : [1] * 6; }
               ^
fail_compilation/fail_arrayop2.d(460): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = [1] * 6 ? [1] * 6 : [1] * 6; }
                         ^
fail_compilation/fail_arrayop2.d(460): Error: array operation `[1] * 6` without destination memory not allowed
    { auto r = [1] * 6 ? [1] * 6 : [1] * 6; }
                                   ^
fail_compilation/fail_arrayop2.d(466): Error: array operation `[1] * 6` without destination memory not allowed
    [1] * 6;
    ^
fail_compilation/fail_arrayop2.d(469): Error: array operation `[1] * 6` without destination memory not allowed
    do {} while ([1] * 6);
                 ^
fail_compilation/fail_arrayop2.d(472): Error: array operation `[1] * 6` without destination memory not allowed
    for ([1] * 6;       // init == ExpStatement
         ^
fail_compilation/fail_arrayop2.d(473): Error: array operation `[1] * 6` without destination memory not allowed
         [1] * 6;
         ^
fail_compilation/fail_arrayop2.d(474): Deprecation: `[1] * 6` has no effect
         [1] * 6) {}
         ^
fail_compilation/fail_arrayop2.d(474): Error: array operation `[1] * 6` without destination memory not allowed
         [1] * 6) {}
         ^
fail_compilation/fail_arrayop2.d(477): Error: array operation `[1] * 6` without destination memory not allowed
    foreach (e; [1] * 6) {}
                ^
fail_compilation/fail_arrayop2.d(480): Error: array operation `[1] * 6` without destination memory not allowed
    if ([1] * 6) {}
        ^
fail_compilation/fail_arrayop2.d(483): Error: array operation `"str"[] + cast(immutable(char))1` without destination memory not allowed
    switch ("str"[] + 1)
            ^
fail_compilation/fail_arrayop2.d(491): Error: CTFE internal error: non-constant value `"uvt"`
        case "uvt"[] - 1:   break;
             ^
fail_compilation/fail_arrayop2.d(491): Error: `"uvt"[] - '\x01'` cannot be interpreted at compile time
        case "uvt"[] - 1:   break;
             ^
---
*/

void test2603() // https://issues.dlang.org/show_bug.cgi?id=2603 - ICE(cgcs.c) on subtracting string literals
{
    auto c1 = [1,2,3] - [1,2,3];

    // this variation is wrong code on D2, ICE ..\ztc\cgcs.c 358 on D1.
    string c2 = "a" - "b";
}

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

    // from https://issues.dlang.org/show_bug.cgi?id=11992
    int[]   arr1;
    int[][] arr2;
    arr1 ~= [1] + a[];         // NG
    arr2 ~= [1] + a[];         // NG
}

void test12381()
{
    double[2] y;
    double h;

    double[2] temp1 = cast(double[2])(h * y[]);
}

float[] test12769(float[] a)
{
    if (a.length < 4)
        return -a[];
    else
        return (-a[])[0..4];
}

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

void test13497()
{
    int[1] a;
    auto b1 = (a[] * a[])[];
    auto b2 = (a[] * a[])[0..1];

    int[] c;
    c = (a[] * a[])[];
    c = (a[] * a[])[0..1];
}

void test13910()
{
    ubyte[][] data;
    size_t segmentId;

    bool isGroup()
    {
        return !!((data[segmentId][28..29]) & (1 << 0));
    }
}

void test14895()
{
    int[] a;
    int[] b = (a[] + 1) ~ a[] * 2;
}

// Test all expressions, which can take arrays as their operands but cannot be a part of array operation.
void test15407exp()
{
    struct S { int[] a; }
    void f(int[] a) {}

    int[] da;
    int[6] sa;

    { auto r = [[1] * 6]; }     // ArrayLiteralExp
    { auto r = [[1] * 6 :
                [1] * 6]; }     // AssocArrayLiteralExp

    //TupleExp
    // StructLiteralExp.elements <- preFunctionParameters in CallExp
    { auto r = S([1] * 6); }

    // NewExp.arguments <- preFunctionParameters
    { auto r = new S([1] * 6); }

    // TODO: TypeidExp
    //auto ti = typeid([1] * 6);
    //auto foo(T)(T t) {}
    //foo(typeid([1] * 6));
    //auto a = [typeid([1] * 6)];

    // CommaExp.e1
    { auto r = ([1] * 6, 1); }

    // AssertExp
    assert([1] * 6,
           cast(char)1 + "abc"[]);

    // CallExp.arguments <- preFunctionParameters
    f([1] * 6);

    // AddrExp, if a CT-known length slice can become an TypeSarray lvalue in the future.
    { auto r = &(([1] * 6)[0..2]); }

    // PtrExp, *([1] * 6).ptr is also invalid -> show better diagnostic
    { auto r = *([1] * 6); }

    // DeleteExp - e1
    delete ([1] * 6);

    // TypeDArray.dotExp, cannot check in ArrayLengthExp.semantic()
    { auto r = (6 * da[]).length; }

    // IndexExp - e1
    { auto x1 = (da[] * 6)[1]; }

    // Pre, PostExp - e1
    ([1] * 6)++;
    --([1] * 6);

    // AssignExp e1
    ([1] * 6) = 10;
    ([1] * 6)[] = 10;

    // BinAssignExp e1
    ([1] * 6) += 1;
    ([1] * 6)[] *= 2;
    ([1] * 6)[] ^^= 3;

    // CatExp e1
    ([1] * 6) ~= 1;
    ([1] * 6)[] ~= 2;

    // Shl, Shr, UshrExp - e1, e2 --> checkIntegralBin
    { auto r = ([1] * 6) << 1; }
    { auto r = ([1] * 6) >> 1; }
    { auto r = ([1] * 6) >>> 1; }

    // AndAnd, OrOrExp - e1, e2
    { auto r = sa[0..5] && [1] * 6; }
    { auto r = sa[0..5] || [1] * 6; }

    // Cmp, Equal, IdentityExp - e1, e2
    { auto r = sa[0..5] <= [1] * 6; }
    { auto r = sa[0..5] == [1] * 6; }
    { auto r = sa[0..5] is [1] * 6; }

    // CondExp - econd, e1, e2
    { auto r = [1] * 6 ? [1] * 6 : [1] * 6; }
}

// Test all statements, which can take arrays as their operands.
void test15407stmt() {
    // ExpStatement - exp
    [1] * 6;

    // DoStatement - condition
    do {} while ([1] * 6);

    // ForStatement - condition, increment
    for ([1] * 6;       // init == ExpStatement
         [1] * 6;
         [1] * 6) {}

    // ForeachStatement - aggr -> lowered to ForStatement
    foreach (e; [1] * 6) {}

    // IfStatement condition
    if ([1] * 6) {}

    // SwitchStatement - condition
    switch ("str"[] + 1)
    {
        case "tus":         break;
        default:            break;
    }
    // CaseStatement - exp
    switch ("tus")
    {
        case "uvt"[] - 1:   break;
        default:            break;
    }
}
