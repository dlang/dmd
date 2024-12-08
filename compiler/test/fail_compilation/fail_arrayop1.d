// REQUIRED_ARGS: -o-

/*
TEST_OUTPUT:
---
fail_compilation/fail_arrayop1.d(95): Error: invalid array operation `a + a` (possible missing [])
    test2199(a + a);
             ^
fail_compilation/fail_arrayop1.d(95):        did you mean to concatenate (`a ~ a`) instead ?
fail_compilation/fail_arrayop1.d(107): Error: invalid array operation `-a` (possible missing [])
    foo(-a);
        ^
fail_compilation/fail_arrayop1.d(116): Error: invalid array operation `-a` (possible missing [])
    r = -a;
        ^
fail_compilation/fail_arrayop1.d(117): Error: invalid array operation `~a` (possible missing [])
    r = ~a;
        ^
fail_compilation/fail_arrayop1.d(118): Error: invalid array operation `a + a` (possible missing [])
    r = a + a;
        ^
fail_compilation/fail_arrayop1.d(118):        did you mean to concatenate (`a ~ a`) instead ?
fail_compilation/fail_arrayop1.d(119): Error: invalid array operation `a - a` (possible missing [])
    r = a - a;
        ^
fail_compilation/fail_arrayop1.d(120): Error: invalid array operation `a * a` (possible missing [])
    r = a * a;
        ^
fail_compilation/fail_arrayop1.d(121): Error: invalid array operation `a / a` (possible missing [])
    r = a / a;
        ^
fail_compilation/fail_arrayop1.d(122): Error: invalid array operation `a % a` (possible missing [])
    r = a % a;
        ^
fail_compilation/fail_arrayop1.d(123): Error: invalid array operation `a ^^ a` (possible missing [])
    r = a ^^ a;
        ^
fail_compilation/fail_arrayop1.d(124): Error: invalid array operation `a & a` (possible missing [])
    r = a & a;
        ^
fail_compilation/fail_arrayop1.d(125): Error: invalid array operation `a | a` (possible missing [])
    r = a | a;
        ^
fail_compilation/fail_arrayop1.d(126): Error: invalid array operation `a ^ a` (possible missing [])
    r = a ^ a;
        ^
fail_compilation/fail_arrayop1.d(133): Error: invalid array operation `a += a[]` (possible missing [])
    a += a[];
      ^
fail_compilation/fail_arrayop1.d(133):        did you mean to concatenate (`a ~= a[]`) instead ?
fail_compilation/fail_arrayop1.d(134): Error: invalid array operation `a -= a[]` (possible missing [])
    a -= a[];
      ^
fail_compilation/fail_arrayop1.d(135): Error: invalid array operation `a *= a[]` (possible missing [])
    a *= a[];
      ^
fail_compilation/fail_arrayop1.d(136): Error: invalid array operation `a /= a[]` (possible missing [])
    a /= a[];
      ^
fail_compilation/fail_arrayop1.d(137): Error: invalid array operation `a %= a[]` (possible missing [])
    a %= a[];
      ^
fail_compilation/fail_arrayop1.d(138): Error: invalid array operation `a ^= a[]` (possible missing [])
    a ^= a[];
      ^
fail_compilation/fail_arrayop1.d(139): Error: invalid array operation `a &= a[]` (possible missing [])
    a &= a[];
      ^
fail_compilation/fail_arrayop1.d(140): Error: invalid array operation `a |= a[]` (possible missing [])
    a |= a[];
      ^
fail_compilation/fail_arrayop1.d(141): Error: invalid array operation `a ^^= a[]` (possible missing [])
    a ^^= a[];
      ^
fail_compilation/fail_arrayop1.d(148): Error: invalid array operation `a[] <<= 1` (possible missing [])
    a[] <<= 1;
        ^
fail_compilation/fail_arrayop1.d(157): Error: invalid array operation `a + b` (possible missing [])
    r[] = a + b;
          ^
fail_compilation/fail_arrayop1.d(157):        did you mean to concatenate (`a ~ b`) instead ?
fail_compilation/fail_arrayop1.d(158): Error: invalid array operation `x + y` (possible missing [])
    r[] = x + y;
          ^
fail_compilation/fail_arrayop1.d(158):        did you mean to concatenate (`x ~ y`) instead ?
fail_compilation/fail_arrayop1.d(159): Error: invalid array operation `"hel" + "lo."` (possible missing [])
    r[] = "hel" + "lo.";
          ^
fail_compilation/fail_arrayop1.d(159):        did you mean to concatenate (`"hel" ~ "lo."`) instead ?
---
*/
void test2199(int[] a)  // https://issues.dlang.org/show_bug.cgi?id=2199 - Segfault using array operation in function call (from fail266.d)
{
// Line 11 starts here
    test2199(a + a);
}

void fail323()      // from fail323.d, maybe was a part of https://issues.dlang.org/show_bug.cgi?id=3471 fix?
{
    void foo(double[]) {}

    auto a = new double[10],
         b = a.dup,
         c = a.dup,
         d = a.dup;
// Line 29 starts here
    foo(-a);
    // a[] = -(b[] * (c[] + 4)) + 5 * d[]; // / 3;
}

void test3903()
{
    int[] a = [1, 2];
    int[] r;
// Line 54 starts here
    r = -a;
    r = ~a;
    r = a + a;
    r = a - a;
    r = a * a;
    r = a / a;
    r = a % a;
    r = a ^^ a;
    r = a & a;
    r = a | a;
    r = a ^ a;
}

void test9459()
{
    int[] a = [1, 2, 3];
// Line 85 starts here
    a += a[];
    a -= a[];
    a *= a[];
    a /= a[];
    a %= a[];
    a ^= a[];
    a &= a[];
    a |= a[];
    a ^^= a[];
}

void test11566()
{
    int[] a;
// Line 105 starts here
    a[] <<= 1;
}

void test14649()
{
    char[] a, b, r;
    string x, y;

// Line 121 starts here
    r[] = a + b;
    r[] = x + y;
    r[] = "hel" + "lo.";
}
