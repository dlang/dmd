/***************************************************/
// with disable this() struct

struct X
{
    @disable this();

    this(int) {}
}

/+
TEST_OUTPUT:
---
fail_compilation/fail9665b.d(110): Error: one path skips field x2
fail_compilation/fail9665b.d(111): Error: one path skips field x3
fail_compilation/fail9665b.d(113): Error: one path skips field x5
fail_compilation/fail9665b.d(114): Error: one path skips field x6
fail_compilation/fail9665b.d(108): Error: constructor fail9665b.S1.this field x1 must be initialized in constructor
fail_compilation/fail9665b.d(108): Error: constructor fail9665b.S1.this field x4 must be initialized in constructor
---
+/
#line 100
struct S1
{
    X x1;
    X x2;
    X x3;
    X[2] x4;
    X[2] x5;
    X[2] x6;
    this(int)
    {
        if (true) x2 = X(1);
        auto n = true ? (x3 = X(1), 1) : 2;

        if (true) x5 = X(1);
        auto m = true ? (x6 = X(1), 1) : 2;
    }
}

/***************************************************/
// with nested struct

/+
TEST_OUTPUT:
---
fail_compilation/fail9665b.d(210): Error: one path skips field x2
fail_compilation/fail9665b.d(211): Error: one path skips field x3
fail_compilation/fail9665b.d(213): Error: one path skips field x5
fail_compilation/fail9665b.d(214): Error: one path skips field x6
fail_compilation/fail9665b.d(208): Error: constructor fail9665b.S2!(X).S2.this field x1 must be initialized in constructor, because it is nested struct
fail_compilation/fail9665b.d(208): Error: constructor fail9665b.S2!(X).S2.this field x4 must be initialized in constructor, because it is nested struct
fail_compilation/fail9665b.d(221): Error: template instance fail9665b.S2!(X) error instantiating
---
+/
#line 200
struct S2(X)
{
    X x1;
    X x2;
    X x3;
    X[2] x4;
    X[2] x5;
    X[2] x6;
    this(int)
    {
        if (true) x2 = X(1);
        auto x = true ? (x3 = X(1), 1) : 2;

        if (true) x5 = X(1);
        auto m = true ? (x6 = X(1), 1) : 2;
    }
}
void test2()
{
    struct X { this(int) {} }
    static assert(X.tupleof.length == 1);
    S2!(X) s;
}
