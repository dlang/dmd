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
fail_compilation/fail9665b.d(39): Error: one path skips field x2
fail_compilation/fail9665b.d(40): Error: one path skips field x3
fail_compilation/fail9665b.d(42): Error: one path skips field x5
fail_compilation/fail9665b.d(43): Error: one path skips field x6
fail_compilation/fail9665b.d(37): Error: constructor fail9665b.S1.this field x1 must be initialized in constructor
fail_compilation/fail9665b.d(37): Error: constructor fail9665b.S1.this field x4 must be initialized in constructor
fail_compilation/fail9665b.d(60): Error: one path skips field x2
fail_compilation/fail9665b.d(61): Error: one path skips field x3
fail_compilation/fail9665b.d(63): Error: one path skips field x5
fail_compilation/fail9665b.d(64): Error: one path skips field x6
fail_compilation/fail9665b.d(58): Error: constructor fail9665b.S2!(X).S2.this field x1 must be initialized in constructor, because it is nested struct
fail_compilation/fail9665b.d(58): Error: constructor fail9665b.S2!(X).S2.this field x4 must be initialized in constructor, because it is nested struct
fail_compilation/fail9665b.d(71): Error: template instance fail9665b.S2!(X) error instantiating
---
+/
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
